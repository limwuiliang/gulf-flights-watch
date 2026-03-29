$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json
$json.flightVolumeHistory = @($json.flightVolumeHistory | Sort-Object { [System.DateTime]::Parse($_.date) })

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)

Write-Host "Sorted dates:"
$json.flightVolumeHistory | ForEach-Object { Write-Host $_.date }
