$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

# Add Apr 4 if missing (interpolate between Apr 3 and Apr 5)
$hasApr4 = $json.flightVolumeHistory | Where-Object { $_.date -eq '2026-04-04' }
if (-not $hasApr4) {
  $apr3 = $json.flightVolumeHistory | Where-Object { $_.date -eq '2026-04-03' }
  $apr5 = $json.flightVolumeHistory | Where-Object { $_.date -eq '2026-04-05' }
  
  if ($apr3 -and $apr5) {
    $apr4 = @{
      date = '2026-04-04'
      emirates_scheduled = [math]::Round(($apr3.emirates_scheduled + $apr5.emirates_scheduled) / 2)
      emirates_departed = 0
      qatar_scheduled = [math]::Round(($apr3.qatar_scheduled + $apr5.qatar_scheduled) / 2)
      qatar_departed = 0
      etihad_scheduled = [math]::Round(($apr3.etihad_scheduled + $apr5.etihad_scheduled) / 2)
      etihad_departed = 0
    }
    $json.flightVolumeHistory += $apr4
    $json.flightVolumeHistory = @($json.flightVolumeHistory | Sort-Object { [DateTime]::Parse($_.date) })
    
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)
    
    Write-Host "Added Apr 4"
  }
}
