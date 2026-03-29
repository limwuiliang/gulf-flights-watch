$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

# Remove duplicate Apr 5 from flightVolumeHistory
$json.flightVolumeHistory = @($json.flightVolumeHistory | Sort-Object date -Unique { $_.date })

# Keep only Apr 5 flights (remove duplicates from add-apr5-real.ps1)
$apr5Flights = @{}
foreach ($airline in $json.airlines) {
  $apr5Flights[$airline.id] = @()
  $seen = @{}
  
  foreach ($flight in $airline.flights) {
    if ($flight.date -eq "2026-04-05") {
      $key = "$($flight.flightNumber)-$($flight.destination)"
      if (-not $seen.ContainsKey($key)) {
        $apr5Flights[$airline.id] += $flight
        $seen[$key] = $true
      }
    }
  }
}

# Rebuild flights arrays: keep all non-Apr5, then add deduplicated Apr5
$json.airlines[0].flights = @($json.airlines[0].flights | Where-Object { $_.date -ne "2026-04-05" }) + $apr5Flights["emirates"]
$json.airlines[1].flights = @($json.airlines[1].flights | Where-Object { $_.date -ne "2026-04-05" }) + $apr5Flights["qatar"]
$json.airlines[2].flights = @($json.airlines[2].flights | Where-Object { $_.date -ne "2026-04-05" }) + $apr5Flights["etihad"]

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)

Write-Host "Cleaned Apr 5 duplicates:"
Write-Host "Emirates Apr 5: $($apr5Flights['emirates'].Count)"
Write-Host "Qatar Apr 5: $($apr5Flights['qatar'].Count)"
Write-Host "Etihad Apr 5: $($apr5Flights['etihad'].Count)"
