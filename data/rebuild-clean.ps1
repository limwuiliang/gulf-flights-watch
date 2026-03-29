# Rebuild scan_results.json from scratch with clean structure
$oldJson = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

# Rebuild flightVolumeHistory cleanly
$history = @()
$dateMap = @{}

foreach ($airline in $oldJson.airlines) {
  foreach ($flight in $airline.flights) {
    if (-not $dateMap.ContainsKey($flight.date)) {
      $dateMap[$flight.date] = @{
        date = $flight.date
        emirates_scheduled = 0
        emirates_departed = 0
        qatar_scheduled = 0
        qatar_departed = 0
        etihad_scheduled = 0
        etihad_departed = 0
      }
    }
    
    $key = $dateMap[$flight.date]
    if ($flight.status -eq 'Departed') {
      $key["$($airline.id)_departed"]++
    } else {
      $key["$($airline.id)_scheduled"]++
    }
  }
}

$history = @($dateMap.Values | Sort-Object { [DateTime]::Parse($_.date) })

# New clean JSON structure
$newJson = @{
  lastScan = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
  scanVersion = 4
  dataNote = 'Live flight data from AeroDataBox. Incremental scans 1x/day. Scheduled=total capacity, Departed=actual flights.'
  flightVolumeHistory = $history
  airlines = $oldJson.airlines
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($newJson | ConvertTo-Json -Depth 10), $utf8)

Write-Host "Rebuilt scan_results.json with clean structure"
Write-Host "Total dates: $($history.Count)"
$history | ForEach-Object {
  Write-Host "  $($_.date): EK($($_.emirates_scheduled)/$($_.emirates_departed)) QR($($_.qatar_scheduled)/$($_.qatar_departed)) EY($($_.etihad_scheduled)/$($_.etihad_departed))"
}
