# Gulf Flights Watch — AeroDataBox scan script
# Pulls live departures from DXB, DOH, AUH for EK, QR, EY
# Queries full 24h day (00:00–24:00 SGT) in two 12h windows to capture all flights
# Groups by actual departure date and appends to flightVolumeHistory

param(
  [string]$RapidApiKey  = "YOUR_RAPIDAPI_KEY_HERE",
  [string]$GithubToken  = "YOUR_GITHUB_TOKEN_HERE",
  [string]$GithubUser   = "limwuiliang",
  [string]$RepoName     = "gulf-flights-watch",
  [string]$RepoPath     = "C:\Users\wuili\gulf-flights-watch"
)

$rapidHost = "aerodatabox.p.rapidapi.com"
$hdrs = @{ "x-rapidapi-host" = $rapidHost; "x-rapidapi-key" = $RapidApiKey }

# Dubai time = UTC+4
$now = [System.DateTime]::UtcNow.AddHours(4)
$d0Start = $now.Date.ToString("yyyy-MM-ddT00:00")
$d0Mid   = $now.Date.AddHours(12).ToString("yyyy-MM-ddT12:00")
$d1Start = $now.Date.AddDays(1).ToString("yyyy-MM-ddT00:00")
$d1Mid   = $now.Date.AddDays(1).AddHours(12).ToString("yyyy-MM-ddT12:00")
$d2Start = $now.Date.AddDays(2).ToString("yyyy-MM-ddT00:00")
$d2Mid   = $now.Date.AddDays(2).AddHours(12).ToString("yyyy-MM-ddT12:00")
$d3Start = $now.Date.AddDays(3).ToString("yyyy-MM-ddT00:00")
$d3Mid   = $now.Date.AddDays(3).AddHours(12).ToString("yyyy-MM-ddT12:00")
$d4Start = $now.Date.AddDays(4).ToString("yyyy-MM-ddT00:00")
$d4Mid   = $now.Date.AddDays(4).AddHours(12).ToString("yyyy-MM-ddT12:00")

# Nine 12h windows to capture 5 days (today through day 4)
$windows = @(
  @{ s=$d0Start; e=$d0Mid },
  @{ s=$d0Mid; e=$d1Start },
  @{ s=$d1Start; e=$d1Mid },
  @{ s=$d1Mid; e=$d2Start },
  @{ s=$d2Start; e=$d2Mid },
  @{ s=$d2Mid; e=$d3Start },
  @{ s=$d3Start; e=$d3Mid },
  @{ s=$d3Mid; e=$d4Start },
  @{ s=$d4Start; e=$d4Mid }
)

Write-Host "Scanning 5 days: $d0Start to $d4Mid (nine 12h windows)"

$queries = @()
foreach ($window in $windows) {
  foreach ($ap in @("DXB", "DOH", "AUH")) {
    $id = if ($ap -eq "DXB") { "emirates" } elseif ($ap -eq "DOH") { "qatar" } else { "etihad" }
    $pfx = if ($ap -eq "DXB") { "EK" } elseif ($ap -eq "DOH") { "QR" } else { "EY" }
    $queries += @{ ap=$ap; id=$id; pfx=$pfx; s=$window.s; e=$window.e }
  }
}

$byAirline = @{ emirates=@(); qatar=@(); etihad=@() }
$flightsByDate = @{}
$seenFlights = @{}  # Deduplicate by flight number + date

foreach ($q in $queries) {
  Start-Sleep -Seconds 3
  $url = "https://aerodatabox.p.rapidapi.com/flights/airports/iata/$($q.ap)/$($q.s)/$($q.e)?direction=Departure&withLeg=true&withCancelled=false&withCodeshared=false&withCargo=false&withPrivate=false"
  try {
    $r = Invoke-RestMethod -Uri $url -Headers $hdrs -Method Get
    $filtered = $r.departures | Where-Object { ($_.number -replace '\s','').StartsWith($q.pfx) }
    Write-Host "$($q.ap) $($q.s): $($filtered.Count) $($q.pfx) flights"
    foreach ($f in $filtered) {
      $dep = $f.departure.scheduledTime.local
      $d = $dep.Substring(0,10)
      $fn = ($f.number -replace '\s','')
      $key = "$fn-$d"
      
      # Skip if already seen (deduplication)
      if ($seenFlights[$key]) {
        continue
      }
      $seenFlights[$key] = $true
      
      if (-not $flightsByDate[$d]) {
        $flightsByDate[$d] = @{ emirates = 0; qatar = 0; etihad = 0 }
      }
      $flightsByDate[$d][$q.id] += 1
      $byAirline[$q.id] += [ordered]@{
        flightNumber    = $fn
        origin          = $q.ap
        transit         = $null
        destination     = "$($f.arrival.airport.iata)"
        destinationName = "$($f.arrival.airport.name)"
        date            = $d
        time            = $dep.Substring(11,5)
        status          = "$($f.status)"
        category        = "Standard"
        priceUSD        = $null
        note            = "Live data via AeroDataBox. Status: $($f.status)"
      }
    }
  } catch {
    Write-Host "$($q.ap) error: $($_.Exception.Message)"
  }
}

$timestamp = [System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$ekJson  = ($byAirline.emirates | ConvertTo-Json -Depth 4 -Compress)
$qrJson  = ($byAirline.qatar    | ConvertTo-Json -Depth 4 -Compress)
$eyJson  = ($byAirline.etihad   | ConvertTo-Json -Depth 4 -Compress)
if ($byAirline.emirates.Count -eq 1) { $ekJson = "[$ekJson]" }
if ($byAirline.qatar.Count -eq 1)    { $qrJson = "[$qrJson]" }
if ($byAirline.etihad.Count -eq 1)   { $eyJson = "[$eyJson]" }

# Build history from grouped dates
$sortedDates = $flightsByDate.Keys | Sort-Object
$historyLines = @()
foreach ($d in $sortedDates) {
  $ek = $flightsByDate[$d].emirates
  $qr = $flightsByDate[$d].qatar
  $ey = $flightsByDate[$d].etihad
  $historyLines += "    { ""date"": ""$d"", ""emirates"": $ek, ""qatar"": $qr, ""etihad"": $ey }"
  Write-Host "  $d : EK=$ek QR=$qr EY=$ey"
}
$historyArray = "[`n" + ($historyLines -join ",`n") + "`n  ]"

# Load existing JSON and merge history
$existingPath = "$RepoPath\data\scan_results.json"
$mergedHistory = @()

if (Test-Path $existingPath) {
  try {
    $existing = [System.IO.File]::ReadAllText($existingPath, [System.Text.Encoding]::UTF8)
    $json_obj = $existing | ConvertFrom-Json
    $mergedHistory = @($json_obj.flightVolumeHistory)
  } catch {
    Write-Host "Warning: Could not parse existing history"
  }
}

# Update or add today's entries
foreach ($d in $sortedDates) {
  $ek = $flightsByDate[$d].emirates
  $qr = $flightsByDate[$d].qatar
  $ey = $flightsByDate[$d].etihad
  
  $existing = $mergedHistory | Where-Object { $_.date -eq $d }
  if ($null -eq $existing) {
    $mergedHistory += [PSCustomObject]@{
      date    = $d
      emirates = $ek
      qatar    = $qr
      etihad  = $ey
    }
  } else {
    $existing.emirates = $ek
    $existing.qatar = $qr
    $existing.etihad = $ey
  }
}

$historyArray = ($mergedHistory | Sort-Object date | ConvertTo-Json -Depth 2 -Compress)

$json = @"
{
  "lastScan": "$timestamp",
  "scanVersion": 3,
  "dataNote": "Live flight data from AeroDataBox API. 5-day window (today 00:00 – day 4 12:00 SGT) captured in nine 12h windows. Grouped by actual flight date. Scans every 12h.",
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

[System.IO.File]::WriteAllText("$RepoPath\data\scan_results.json", $json, [System.Text.Encoding]::UTF8)
Write-Host "scan_results.json written with full 24h day coverage"

# Git push
Set-Location $RepoPath
git remote set-url origin "https://${GithubUser}:${GithubToken}@github.com/${GithubUser}/${RepoName}.git"
git add data/scan_results.json
git commit -m "scan: full 24h day coverage (00:00–24:00 SGT, deduped) $timestamp"
git push origin main
git remote set-url origin "https://github.com/${GithubUser}/${RepoName}.git"
Write-Host "Pushed to GitHub."
