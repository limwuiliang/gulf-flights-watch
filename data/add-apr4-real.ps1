$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

Write-Host "Adding Apr 4 flights (cloned from Apr 3)..."

foreach ($airline in $json.airlines) {
  $apr3Flights = @($airline.flights | Where-Object { $_.date -eq '2026-04-03' })
  Write-Host "  $($airline.name): found $($apr3Flights.Count) Apr 3 flights to clone"
  
  foreach ($flight in $apr3Flights) {
    $clone = $flight | ConvertTo-Json | ConvertFrom-Json
    $clone.date = '2026-04-04'
    $clone.status = 'Expected'
    $clone.note = "Forecast flight (based on Apr 3 pattern)"
    $airline.flights += $clone
  }
}

# Update flightVolumeHistory for Apr 4 (count the new flights)
$apr4Entry = $json.flightVolumeHistory | Where-Object { $_.date -eq '2026-04-04' }
if (-not $apr4Entry) {
  $apr4Entry = @{ date = '2026-04-04'; emirates_scheduled = 0; emirates_departed = 0; qatar_scheduled = 0; qatar_departed = 0; etihad_scheduled = 0; etihad_departed = 0 }
  $json.flightVolumeHistory += $apr4Entry
}

# Count Apr 4 flights by airline
$apr4ek = @($json.airlines[0].flights | Where-Object { $_.date -eq '2026-04-04' }).Count
$apr4qr = @($json.airlines[1].flights | Where-Object { $_.date -eq '2026-04-04' }).Count
$apr4ey = @($json.airlines[2].flights | Where-Object { $_.date -eq '2026-04-04' }).Count

$apr4Entry.emirates_scheduled = $apr4ek
$apr4Entry.qatar_scheduled = $apr4qr
$apr4Entry.etihad_scheduled = $apr4ey

$json.lastScan = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)

Write-Host "`nApr 4 now has:"
Write-Host "  Emirates: $apr4ek scheduled"
Write-Host "  Qatar: $apr4qr scheduled"
Write-Host "  Etihad: $apr4ey scheduled"
