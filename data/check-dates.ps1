$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json
$dates = $json.flightVolumeHistory | Select-Object date
Write-Host "Dates in flightVolumeHistory:"
$dates | ForEach-Object { Write-Host $_.date }
Write-Host "`nTotal flights per airline:"
Write-Host "Emirates: $($json.airlines[0].flights.Count)"
Write-Host "Qatar: $($json.airlines[1].flights.Count)"
Write-Host "Etihad: $($json.airlines[2].flights.Count)"
