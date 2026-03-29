$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

# Rebuild flightVolumeHistory from flights data
$history = @{}

foreach ($airline in $json.airlines) {
  foreach ($flight in $airline.flights) {
    if (-not $history.ContainsKey($flight.date)) {
      $history[$flight.date] = @{
        date = $flight.date
        emirates_scheduled = 0
        emirates_departed = 0
        qatar_scheduled = 0
        qatar_departed = 0
        etihad_scheduled = 0
        etihad_departed = 0
      }
    }
    
    $dateKey = $history[$flight.date]
    $statusKey = if ($flight.status -eq "Departed") { "_departed" } else { "_scheduled" }
    $airlineKey = "$($airline.id)$statusKey"
    $dateKey[$airlineKey]++
  }
}

$json.flightVolumeHistory = @($history.Values | Sort-Object date)
$json.lastScan = [System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)

Write-Host "Rebuilt flightVolumeHistory:"
$json.flightVolumeHistory | ForEach-Object { 
  Write-Host "$($_.date): EK(S=$($_.emirates_scheduled),D=$($_.emirates_departed)) QR(S=$($_.qatar_scheduled),D=$($_.qatar_departed)) EY(S=$($_.etihad_scheduled),D=$($_.etihad_departed))"
}
