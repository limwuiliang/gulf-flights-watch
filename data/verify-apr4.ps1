$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json
$apr4Count = 0
foreach ($a in $json.airlines) {
  $c = @($a.flights | Where-Object { $_.date -eq '2026-04-04' }).Count
  Write-Host "$($a.name): $c flights on Apr 4"
  $apr4Count += $c
}
Write-Host "Total Apr 4 flights: $apr4Count"
