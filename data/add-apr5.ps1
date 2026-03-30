$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

Write-Host "Adding Apr 5 flights (cloned from Apr 3)..."

foreach ($airline in $json.airlines) {
  $apr3Flights = @($airline.flights | Where-Object { $_.date -eq '2026-04-03' })
  Write-Host "  $($airline.name): cloning $($apr3Flights.Count) Apr 3 flights to Apr 5"
  
  foreach ($flight in $apr3Flights) {
    $clone = $flight | ConvertTo-Json | ConvertFrom-Json
    $clone.date = '2026-04-05'
    $clone.status = 'Expected'
    $clone.note = "Forecast flight (based on Apr 3 pattern)"
    $airline.flights += $clone
  }
}

# Update flightVolumeHistory for Apr 5
$apr5Entry = $json.flightVolumeHistory | Where-Object { $_.date -eq '2026-04-05' }
if ($apr5Entry) {
  $apr5Entry.emirates_scheduled = 162
  $apr5Entry.emirates_departed = 0
  $apr5Entry.qatar_scheduled = 181
  $apr5Entry.qatar_departed = 0
  $apr5Entry.etihad_scheduled = 47
  $apr5Entry.etihad_departed = 0
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
