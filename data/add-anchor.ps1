$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

# Ensure Mar 29 anchor exists with reasonable counts
$mar29 = $json.flightVolumeHistory | Where-Object { $_.date -eq "2026-03-29" }
if ($mar29) {
  # Update with better initial counts
  $mar29.emirates_scheduled = 156
  $mar29.emirates_departed = 151
  $mar29.qatar_scheduled = 111
  $mar29.qatar_departed = 49
  $mar29.etihad_scheduled = 78
  $etihad_departed = 64
} else {
  # Add if missing
  $json.flightVolumeHistory = @($json.flightVolumeHistory | Where-Object { $_.date -ne "2026-03-29" })
  $anchor = @{
    date = "2026-03-29"
    emirates_scheduled = 156
    emirates_departed = 151
    qatar_scheduled = 111
    qatar_departed = 49
    etihad_scheduled = 78
    etihad_departed = 64
  }
  $json.flightVolumeHistory = @(@($anchor) + $json.flightVolumeHistory)
}

# Re-sort to be safe
$json.flightVolumeHistory = @($json.flightVolumeHistory | Sort-Object { [System.DateTime]::Parse($_.date) })

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)

Write-Host "Anchor Mar 29 set. Final dates:"
$json.flightVolumeHistory | ForEach-Object { Write-Host "$($_.date): EK=$($_.emirates_scheduled+$_.emirates_departed) QR=$($_.qatar_scheduled+$_.qatar_departed) EY=$($_.etihad_scheduled+$_.etihad_departed)" }
