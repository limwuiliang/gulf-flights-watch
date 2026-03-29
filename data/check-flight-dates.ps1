$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

# Check unique dates in flights
$dates = @{}
foreach ($airline in $json.airlines) {
  foreach ($flight in $airline.flights) {
    $d = $flight.date
    if (-not $dates.ContainsKey($d)) {
      $dates[$d] = 0
    }
    $dates[$d]++
  }
}

Write-Host "Flight dates distribution:"
$dates.GetEnumerator() | Sort-Object Name | ForEach-Object {
  Write-Host "  $($_.Key): $($_.Value) flights"
}

Write-Host "`nTotal flights: $(($json.airlines | ForEach-Object { $_.flights.Count } | Measure-Object -Sum).Sum)"
Write-Host "Sample flight dates (first 10 per airline):"
foreach ($airline in $json.airlines) {
  Write-Host "`n$($airline.name):"
  $airline.flights | Select-Object -First 10 | ForEach-Object { Write-Host "  $($_.flightNumber) on $($_.date)" }
}
