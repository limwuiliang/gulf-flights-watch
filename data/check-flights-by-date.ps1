$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json
$dates = @{}
foreach ($a in $json.airlines) {
  foreach ($f in $a.flights) {
    if (-not $dates.ContainsKey($f.date)) {
      $dates[$f.date] = 0
    }
    $dates[$f.date]++
  }
}
Write-Host "Flights by date:"
$dates.GetEnumerator() | Sort-Object Name | ForEach-Object {
  Write-Host "  $($_.Key): $($_.Value) flights"
}
