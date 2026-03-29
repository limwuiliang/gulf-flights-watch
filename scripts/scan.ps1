# Gulf Flights Watch — AeroDataBox scan script (1x daily, incremental)
# Incremental scans: only today + new forecast dates queried (not old dates)
# Typical: 6-8 API calls per scan (today + 1 new date)
# 1 scan/day = ~6-8 units/day, well within 600/month budget (~180-240/month)

param(
  [string]$RapidApiKey  = "YOUR_RAPIDAPI_KEY_HERE",
  [string]$GithubToken  = "YOUR_GITHUB_TOKEN_HERE",
  [string]$GithubUser   = "limwuiliang",
  [string]$RepoName     = "gulf-flights-watch",
  [string]$RepoPath     = "C:\Users\wuili\gulf-flights-watch"
)

$rapidHost = "aerodatabox.p.rapidapi.com"
$hdrs = @{ "x-rapidapi-host" = $rapidHost; "x-rapidapi-key" = $RapidApiKey }

$now = [System.DateTime]::UtcNow.AddHours(4)

# Anchor date: Mar 29, 2026
$anchorDate = [System.DateTime]::Parse("2026-03-29")
$todayDate = $now.Date
$tomorrowDate = $todayDate.AddDays(1)
$lastForecastDate = $todayDate.AddDays(6)

# Load existing history to see what dates we already have
$existingHistory = @()
$existingByDate = @{}
if (Test-Path "$RepoPath\data\scan_results.json") {
  try {
    $existing = Get-Content "$RepoPath\data\scan_results.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $existingHistory = $existing.flightVolumeHistory
    foreach ($entry in $existingHistory) {
      $existingByDate[$entry.date] = $entry
    }
    Write-Host "Loaded existing history with $($existingByDate.Count) dates"
  } catch {
    Write-Host "Could not load existing history, will scan full range"
  }
}

# Determine which dates to scan:
# - Always scan today (to get updated Departed counts)
# - Scan any dates in the rolling window (today through today+6) that we don't have yet
$datesToScan = @()
$datesToScan += $todayDate  # Always update today's departures

# Add any new dates in the rolling forecast window that aren't in history yet
for ($i = 1; $i -le 6; $i++) {
  $d = $todayDate.AddDays($i)
  if (-not $existingByDate[$d.ToString("yyyy-MM-dd")]) {
    $datesToScan += $d
  }
}

# Build windows only for dates we need to scan
$windows = @()
foreach ($d in $datesToScan) {
  $dayStart = $d.ToString("yyyy-MM-ddT00:00")
  $dayMid   = $d.AddHours(12).ToString("yyyy-MM-ddT12:00")
  $windows += @{ s=$dayStart; e=$dayMid; date=$d.ToString("yyyy-MM-dd") }
  $windows += @{ s=$dayMid; e=$d.AddDays(1).ToString("yyyy-MM-ddT00:00"); date=$d.ToString("yyyy-MM-dd") }
}

Write-Host "Scanning only new dates: $($datesToScan -join ', ') ($($windows.Count) windows × 3 airports = $($windows.Count * 3) API calls)"

$queries = @()
foreach ($window in $windows) {
  foreach ($ap in @("DXB", "DOH", "AUH")) {
    $id = if ($ap -eq "DXB") { "emirates" } elseif ($ap -eq "DOH") { "qatar" } else { "etihad" }
    $pfx = if ($ap -eq "DXB") { "EK" } elseif ($ap -eq "DOH") { "QR" } else { "EY" }
    $queries += @{ ap=$ap; id=$id; pfx=$pfx; s=$window.s; e=$window.e }
  }
}

$byAirline = @{ emirates=@(); qatar=@(); etihad=@() }
$flightsByDateStatus = @{}  # {date}{status} -> count
$seenFlights = @{}

foreach ($q in $queries) {
  Start-Sleep -Seconds 5  # Increased from 2s to 5s per call to avoid rate limits
  $url = "https://aerodatabox.p.rapidapi.com/flights/airports/iata/$($q.ap)/$($q.s)/$($q.e)?direction=Departure&withLeg=true&withCancelled=false&withCodeshared=false&withCargo=false&withPrivate=false"
  
  # Retry logic for rate limits
  $maxRetries = 3
  $retryCount = 0
  $success = $false
  
  while ($retryCount -lt $maxRetries -and -not $success) {
    try {
      $r = Invoke-RestMethod -Uri $url -Headers $hdrs -Method Get
      $filtered = $r.departures | Where-Object { ($_.number -replace '\s','').StartsWith($q.pfx) }
      foreach ($f in $filtered) {
        $dep = $f.departure.scheduledTime.local
        $d = $dep.Substring(0,10)
        $fn = ($f.number -replace '\s','')
        $status = $f.status  # "Expected", "Departed", etc.
        $key = "$fn-$d"
        
        if ($seenFlights[$key]) { continue }
        $seenFlights[$key] = $true
        
        # Track by date + status for chart
        if (-not $flightsByDateStatus[$d]) {
          $flightsByDateStatus[$d] = @{ 
            emirates_expected = 0; emirates_departed = 0
            qatar_expected = 0; qatar_departed = 0
            etihad_expected = 0; etihad_departed = 0
          }
        }
        $statusKey = "$($q.id)_$($status.ToLower())"
        $flightsByDateStatus[$d][$statusKey] += 1
        
        # Add to flights array
        $byAirline[$q.id] += [ordered]@{
          flightNumber    = $fn
          origin          = $q.ap
          transit         = $null
          destination     = "$($f.arrival.airport.iata)"
          destinationName = "$($f.arrival.airport.name)"
          date            = $d
          time            = $dep.Substring(11,5)
          status          = $status
          category        = "Standard"
          priceUSD        = $null
          note            = "Live data via AeroDataBox. Status: $status"
        }
      }
      $success = $true
    } catch {
      $errorMsg = $_.Exception.Message
      if ($errorMsg -match "429|Too Many Requests") {
        $retryCount++
        $waitTime = 30 + ($retryCount * 30)  # 60s, 90s, 120s
        Write-Host "$($q.ap) $($q.s) rate limited (429). Retry $retryCount/$maxRetries after ${waitTime}s..." -ForegroundColor Yellow
        Start-Sleep -Seconds $waitTime
      } else {
        Write-Host "$($q.ap) $($q.s) error: $errorMsg" -ForegroundColor Yellow
        $success = $true  # Don't retry on non-429 errors
      }
    }
  }
}

$timestamp = [System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$ekJson  = ($byAirline.emirates | ConvertTo-Json -Depth 4 -Compress)
$qrJson  = ($byAirline.qatar    | ConvertTo-Json -Depth 4 -Compress)
$eyJson  = ($byAirline.etihad   | ConvertTo-Json -Depth 4 -Compress)
if ($byAirline.emirates.Count -eq 1) { $ekJson = "[$ekJson]" }
if ($byAirline.qatar.Count -eq 1)    { $qrJson = "[$qrJson]" }
if ($byAirline.etihad.Count -eq 1)   { $eyJson = "[$eyJson]" }

# Merge strategy (optimized for incremental scans):
# - PRESERVE: All existing dates (Scheduled + Departed both frozen)
# - UPDATE: Only today's Departed counts (refresh with latest flight data)
# - ADD: Any new forecast dates (today+1 through today+6) with fresh Scheduled counts
Write-Host "`nMerging history (incremental scan):"
$mergedHistory = @()

# First, keep all dates before today unchanged
$sortedDates = $existingByDate.Keys | Sort-Object
foreach ($oldDate in $sortedDates) {
  $dateObj = [System.DateTime]::Parse($oldDate)
  if ($dateObj -lt $todayDate) {
    # Old date - preserve as-is
    $mergedHistory += $existingByDate[$oldDate]
  }
}

# Now handle today and forward dates
for ($i = 0; $i -le 6; $i++) {
  $d = $todayDate.AddDays($i).ToString("yyyy-MM-dd")
  $dateObj = [System.DateTime]::Parse($d)
  
  if ($dateObj -eq $todayDate) {
    # Today: Update Departed counts, preserve Scheduled from previous scan
    $ek_dep = if ($flightsByDateStatus[$d]) { $flightsByDateStatus[$d].emirates_departed } else { 0 }
    $qr_dep = if ($flightsByDateStatus[$d]) { $flightsByDateStatus[$d].qatar_departed } else { 0 }
    $ey_dep = if ($flightsByDateStatus[$d]) { $flightsByDateStatus[$d].etihad_departed } else { 0 }
    
    $ek_sch = if ($existingByDate[$d]) { $existingByDate[$d].emirates_scheduled } else { 0 }
    $qr_sch = if ($existingByDate[$d]) { $existingByDate[$d].qatar_scheduled } else { 0 }
    $ey_sch = if ($existingByDate[$d]) { $existingByDate[$d].etihad_scheduled } else { 0 }
    
    $mergedHistory += @{
      date = $d
      emirates_scheduled = $ek_sch
      emirates_departed = $ek_dep
      qatar_scheduled = $qr_sch
      qatar_departed = $qr_dep
      etihad_scheduled = $ey_sch
      etihad_departed = $ey_dep
    }
    Write-Host "  $d : EK=$($ek_sch) sch | $($ek_dep) dep (TODAY-UPDATED) | QR=$($qr_sch) sch | $($qr_dep) dep | EY=$($ey_sch) sch | $($ey_dep) dep"
  } elseif ($existingByDate[$d]) {
    # Future date that exists in history - preserve unchanged
    $mergedHistory += $existingByDate[$d]
  } else {
    # New future date - use data from fresh API scan (Scheduled from new scan, Departed=0)
    $ek_sch = if ($flightsByDateStatus[$d]) { $flightsByDateStatus[$d].emirates_expected } else { 0 }
    $qr_sch = if ($flightsByDateStatus[$d]) { $flightsByDateStatus[$d].qatar_expected } else { 0 }
    $ey_sch = if ($flightsByDateStatus[$d]) { $flightsByDateStatus[$d].etihad_expected } else { 0 }
    
    $mergedHistory += @{
      date = $d
      emirates_scheduled = $ek_sch
      emirates_departed = 0
      qatar_scheduled = $qr_sch
      qatar_departed = 0
      etihad_scheduled = $ey_sch
      etihad_departed = 0
    }
    Write-Host "  $d : EK=$($ek_sch) sch | 0 dep (NEW) | QR=$($qr_sch) sch | 0 dep | EY=$($ey_sch) sch | 0 dep"
  }
}

# Build JSON array from merged history
$historyLines = @()
foreach ($entry in $mergedHistory) {
  $historyLines += "    { ""date"": ""$($entry.date)"", ""emirates_scheduled"": $($entry.emirates_scheduled), ""emirates_departed"": $($entry.emirates_departed), ""qatar_scheduled"": $($entry.qatar_scheduled), ""qatar_departed"": $($entry.qatar_departed), ""etihad_scheduled"": $($entry.etihad_scheduled), ""etihad_departed"": $($entry.etihad_departed) }"
}
$historyArray = "[`n" + ($historyLines -join ",`n") + "`n  ]"

$json = @"
{
  "lastScan": "$timestamp",
  "scanVersion": 4,
  "dataNote": "Live flight data from AeroDataBox API. Incremental scans: only today + new forecast dates queried. Old dates frozen (no re-queries). Today: Departed updated, Scheduled preserved. New dates: Scheduled from fresh API, Departed=0. Scans every 12h (2x/day). Minimal API cost (~6-8 calls/scan).",
  "airlines": [
    {
      "id": "emirates", "name": "Emirates", "iata": "EK", "hub": "DXB",
      "color": "#D71921", "status": "REDUCED", "statusLabel": "Reduced Schedule",
      "source": "https://www.emirates.com/us/english/help/travel-updates/",
      "lastUpdated": "2026-03-28",
      "summary": "Operating a reduced flight schedule following partial reopening of regional airspace. Travel waiver in effect for Feb 28 - Apr 15 travelers. Rebooking allowed to May 31. Up to 9 free changes.",
      "advisory": { "affectedDates": { "from": "2026-02-28", "to": "2026-04-15" }, "rebookBy": "2026-05-31", "waiverChanges": 9, "airspaceStatus": "PARTIAL_REOPEN" },
      "flights": $ekJson
    },
    {
      "id": "qatar", "name": "Qatar Airways", "iata": "QR", "hub": "DOH",
      "color": "#5C0632", "status": "RESTRICTED", "statusLabel": "Restricted / Limited Corridor",
      "source": "https://www.qatarairways.com/en/rebooking-options.html",
      "lastUpdated": "2026-03-26",
      "summary": "Resuming expanded network via dedicated flight corridors. 90+ destinations restored as of Mar 26. Schedule valid to Apr 15. Waiver: bookings Feb 28-Jun 15 eligible for free changes or refund.",
      "advisory": { "affectedDates": { "from": "2026-02-28", "to": "2026-06-15" }, "rebookBy": "2026-10-31", "waiverChanges": null, "airspaceStatus": "DEDICATED_CORRIDOR" },
      "flights": $qrJson
    },
    {
      "id": "etihad", "name": "Etihad Airways", "iata": "EY", "hub": "AUH",
      "color": "#BD8B13", "status": "UNKNOWN", "statusLabel": "Data Unavailable",
      "source": "https://www.etihad.com/en/help",
      "lastUpdated": null,
      "summary": "Travel advisory page not accessible this scan cycle. Etihad is Abu Dhabi-based and may face corridor restrictions. Check etihad.com directly.",
      "advisory": null,
      "flights": $eyJson
    }
  ],
  "flightVolumeHistory": $historyArray
}
"@

# Ensure UTF-8 without BOM
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$RepoPath\data\scan_results.json", $json, $utf8)
Write-Host "`nDone - 6-day scan with status tracking"

# Git push
Set-Location $RepoPath
git remote set-url origin "https://${GithubUser}:${GithubToken}@github.com/${GithubUser}/${RepoName}.git"
git add data/scan_results.json
git commit -m "scan: 6-day window with Expected/Departed status tracking $timestamp"
git push origin main
git remote set-url origin "https://github.com/${GithubUser}/${RepoName}.git"
Write-Host "Pushed to GitHub."
