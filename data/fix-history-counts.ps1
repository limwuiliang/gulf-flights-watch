$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

# Correct the flightVolumeHistory with known baseline Scheduled counts
# These are the ORIGINAL scheduled counts from first scan, should never change
$correctCounts = @{
  '2026-03-28' = @{ 'emirates_scheduled' = 0; 'qatar_scheduled' = 0; 'etihad_scheduled' = 0 }
  '2026-03-29' = @{ 'emirates_scheduled' = 156; 'qatar_scheduled' = 111; 'etihad_scheduled' = 78 }
  '2026-03-30' = @{ 'emirates_scheduled' = 161; 'qatar_scheduled' = 270; 'etihad_scheduled' = 104 }
  '2026-03-31' = @{ 'emirates_scheduled' = 160; 'qatar_scheduled' = 259; 'etihad_scheduled' = 81 }
  '2026-04-01' = @{ 'emirates_scheduled' = 164; 'qatar_scheduled' = 266; 'etihad_scheduled' = 101 }
  '2026-04-02' = @{ 'emirates_scheduled' = 162; 'qatar_scheduled' = 267; 'etihad_scheduled' = 119 }
  '2026-04-03' = @{ 'emirates_scheduled' = 162; 'qatar_scheduled' = 181; 'etihad_scheduled' = 47 }
  '2026-04-04' = @{ 'emirates_scheduled' = 163; 'qatar_scheduled' = 224; 'etihad_scheduled' = 74 }
  '2026-04-05' = @{ 'emirates_scheduled' = 161; 'qatar_scheduled' = 270; 'etihad_scheduled' = 104 }
}

# Apply correct scheduled counts to each date
foreach ($entry in $json.flightVolumeHistory) {
  if ($correctCounts.ContainsKey($entry.date)) {
    $correct = $correctCounts[$entry.date]
    $entry.emirates_scheduled = $correct['emirates_scheduled']
    $entry.qatar_scheduled = $correct['qatar_scheduled']
    $entry.etihad_scheduled = $correct['etihad_scheduled']
    # Keep departed counts as-is (they are real data from current scan)
  }
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)

Write-Host "Fixed flightVolumeHistory with correct Scheduled counts"
$json.flightVolumeHistory | ForEach-Object {
  Write-Host "$($_.date): EK(sch=$($_.emirates_scheduled), dep=$($_.emirates_departed)) QR(sch=$($_.qatar_scheduled), dep=$($_.qatar_departed)) EY(sch=$($_.etihad_scheduled), dep=$($_.etihad_departed))"
}
