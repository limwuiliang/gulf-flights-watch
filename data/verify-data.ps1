$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json
Write-Host "First 3 entries in flightVolumeHistory:"
for ($i = 0; $i -lt 3 -and $i -lt $json.flightVolumeHistory.Count; $i++) {
  $entry = $json.flightVolumeHistory[$i]
  Write-Host "Date: $($entry.date), EK scheduled: $($entry.emirates_scheduled), EK departed: $($entry.emirates_departed)"
}
