$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

# Add Apr 4 flights by cloning from Apr 3 (with date changed)
foreach ($airline in $json.airlines) {
  $apr3Flights = $airline.flights | Where-Object { $_.date -eq '2026-04-03' }
  $apr4Flights = @()
  
  foreach ($flight in $apr3Flights) {
    $clone = $flight | ConvertTo-Json | ConvertFrom-Json
    $clone.date = '2026-04-04'
    $clone.status = 'Expected'
    $clone.note = "Forecast flight (based on Apr 3 pattern)"
    $apr4Flights += $clone
  }
  
  $airline.flights += $apr4Flights
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)

Write-Host "Added Apr 4 flights (cloned from Apr 3)"
