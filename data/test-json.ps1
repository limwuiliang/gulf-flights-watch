try {
  $json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json
  Write-Host "JSON valid"
  Write-Host "Total airlines: $($json.airlines.Count)"
  $total = 0
  foreach ($a in $json.airlines) {
    Write-Host "  $($a.name): $($a.flights.Count) flights"
    $total += $a.flights.Count
  }
  Write-Host "Total flights: $total"
} catch {
  Write-Host "ERROR: $_"
}
