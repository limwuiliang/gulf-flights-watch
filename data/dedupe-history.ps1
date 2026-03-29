$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json
$json.flightVolumeHistory = @($json.flightVolumeHistory | Group-Object date | ForEach-Object { $_.Group[0] })
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)
Write-Host "Removed duplicate Apr 5 from history"
