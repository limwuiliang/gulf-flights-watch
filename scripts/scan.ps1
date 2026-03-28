# Gulf Flights Watch — AeroDataBox scan script
# Pulls live departures from DXB, DOH, AUH for EK, QR, EY
# Writes to data/scan_results.json and pushes to GitHub

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
$w1s = $now.ToString("yyyy-MM-ddTHH:mm")
$w1e = $now.AddHours(12).ToString("yyyy-MM-ddTHH:mm")
$w2s = $now.AddHours(12).ToString("yyyy-MM-ddTHH:mm")
$w2e = $now.AddHours(24).ToString("yyyy-MM-ddTHH:mm")

$queries = @(
  @{ ap="DXB"; id="emirates"; pfx="EK"; s=$w1s; e=$w1e },
  @{ ap="DXB"; id="emirates"; pfx="EK"; s=$w2s; e=$w2e },
  @{ ap="DOH"; id="qatar";    pfx="QR"; s=$w1s; e=$w1e },
  @{ ap="DOH"; id="qatar";    pfx="QR"; s=$w2s; e=$w2e },
  @{ ap="AUH"; id="etihad";   pfx="EY"; s=$w1s; e=$w1e },
  @{ ap="AUH"; id="etihad";   pfx="EY"; s=$w2s; e=$w2e }
)

$byAirline = @{ emirates=@(); qatar=@(); etihad=@() }

foreach ($q in $queries) {
  Start-Sleep -Seconds 3
  $url = "https://aerodatabox.p.rapidapi.com/flights/airports/iata/$($q.ap)/$($q.s)/$($q.e)?direction=Departure&withLeg=true&withCancelled=false&withCodeshared=false&withCargo=false&withPrivate=false"
  try {
    $r = Invoke-RestMethod -Uri $url -Headers $hdrs -Method Get
    $filtered = $r.departures | Where-Object { ($_.number -replace '\s','').StartsWith($q.pfx) }
    Write-Host "$($q.ap) $($q.s): $($filtered.Count) $($q.pfx) flights"
    foreach ($f in $filtered) {
      $dep = $f.departure.scheduledTime.local
      $byAirline[$q.id] += [ordered]@{
        flightNumber    = ($f.number -replace '\s','')
        origin          = $q.ap
        transit         = $null
        destination     = "$($f.arrival.airport.iata)"
        destinationName = "$($f.arrival.airport.name)"
        date            = $dep.Substring(0,10)
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

$ekCount = $byAirline.emirates.Count
$qrCount = $byAirline.qatar.Count
$eyCount = $byAirline.etihad.Count

$json = @"
{
  "lastScan": "$timestamp",
  "scanVersion": 3,
  "dataNote": "Live flight data from AeroDataBox API. Today + 24h window from DXB, DOH, AUH. Scans every 12h.",
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
  "flightVolumeHistory": [
    { "date": "2026-02-27", "emirates": 85, "qatar": 92, "etihad": 78 },
    { "date": "2026-02-28", "emirates": 60, "qatar": 30, "etihad": 55 },
    { "date": "2026-03-01", "emirates": 45, "qatar": 15, "etihad": 40 },
    { "date": "2026-03-05", "emirates": 38, "qatar": 12, "etihad": 35 },
    { "date": "2026-03-10", "emirates": 32, "qatar": 10, "etihad": 28 },
    { "date": "2026-03-15", "emirates": 35, "qatar": 8,  "etihad": 30 },
    { "date": "2026-03-20", "emirates": 40, "qatar": 18, "etihad": 32 },
    { "date": "2026-03-25", "emirates": 48, "qatar": 22, "etihad": 38 },
    { "date": "2026-03-28", "emirates": $ekCount, "qatar": $qrCount, "etihad": $eyCount }
  ]
}
"@

[System.IO.File]::WriteAllText("$RepoPath\data\scan_results.json", $json, [System.Text.Encoding]::UTF8)
Write-Host "scan_results.json written: EK=$ekCount QR=$qrCount EY=$eyCount"

# Git push
Set-Location $RepoPath
git remote set-url origin "https://${GithubUser}:${GithubToken}@github.com/${GithubUser}/${RepoName}.git"
git add data/scan_results.json
git commit -m "scan: live AeroDataBox update $timestamp (EK=$ekCount QR=$qrCount EY=$eyCount)"
git push origin main
git remote set-url origin "https://github.com/${GithubUser}/${RepoName}.git"
Write-Host "Pushed to GitHub."
