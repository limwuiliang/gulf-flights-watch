$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

Write-Host "Adding Apr 4 flights (cloned from Apr 3)..."

foreach ($airline in $json.airlines) {
  $apr3Flights = @($airline.flights | Where-Object { $_.date -eq '2026-04-03' })
  Write-Host "  $($airline.name): cloning $($apr3Flights.Count) Apr 3 flights to Apr 4"
  
  foreach ($flight in $apr3Flights) {
    $clone = $flight | ConvertTo-Json | ConvertFrom-Json
    $clone.date = '2026-04-04'
    $clone.status = 'Expected'
    $clone.note = "Forecast flight (based on Apr 3 pattern)"
    $airline.flights += $clone
  }
}

$json.lastScan = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)

Write-Host "`nDone. Total flights now:"
$total = 0
foreach ($a in $json.airlines) {
  Write-Host "  $($a.name): $($a.flights.Count)"
  $total += $a.flights.Count
}
Write-Host "  TOTAL: $total"
