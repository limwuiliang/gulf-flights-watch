# Gulf Flights Watch — AeroDataBox scan script (2x daily)
# Captures 6-day window with flight status (Expected/Departed)
# 12 windows × 3 airports = 36 API calls per scan (~36 units)
# 2 scans/day = ~72 units/day, well within 600/month free tier

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

# Build 6 days of 12h windows (12 total)
$windows = @()
for ($i = 0; $i -lt 6; $i++) {
  $dayStart = $now.Date.AddDays($i).ToString("yyyy-MM-ddT00:00")
  $dayMid   = $now.Date.AddDays($i).AddHours(12).ToString("yyyy-MM-ddT12:00")
  $windows += @{ s=$dayStart; e=$dayMid }
  $windows += @{ s=$dayMid; e=$now.Date.AddDays($i+1).ToString("yyyy-MM-ddT00:00") }
}

Write-Host "Scanning 6 days: $($now.Date.ToString('yyyy-MM-dd')) to $(($now.Date.AddDays(5)).ToString('yyyy-MM-dd')) (12 windows × 3 airports = 36 API calls)"

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
  Start-Sleep -Seconds 2
  $url = "https://aerodatabox.p.rapidapi.com/flights/airports/iata/$($q.ap)/$($q.s)/$($q.e)?direction=Departure&withLeg=true&withCancelled=false&withCodeshared=false&withCargo=false&withPrivate=false"
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
  } catch {
    Write-Host "$($q.ap) $($q.s) error: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

$timestamp = [System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$ekJson  = ($byAirline.emirates | ConvertTo-Json -Depth 4 -Compress)
$qrJson  = ($byAirline.qatar    | ConvertTo-Json -Depth 4 -Compress)
$eyJson  = ($byAirline.etihad   | ConvertTo-Json -Depth 4 -Compress)
if ($byAirline.emirates.Count -eq 1) { $ekJson = "[$ekJson]" }
if ($byAirline.qatar.Count -eq 1)    { $qrJson = "[$qrJson]" }
if ($byAirline.etihad.Count -eq 1)   { $eyJson = "[$eyJson]" }

# Build history with Expected + Departed
$sortedDates = $flightsByDateStatus.Keys | Sort-Object
Write-Host "`nFlight counts by date (Expected + Departed):"
$historyLines = @()
foreach ($d in $sortedDates) {
  $ek_exp = $flightsByDateStatus[$d].emirates_expected
  $ek_dep = $flightsByDateStatus[$d].emirates_departed
  $qr_exp = $flightsByDateStatus[$d].qatar_expected
  $qr_dep = $flightsByDateStatus[$d].qatar_departed
  $ey_exp = $flightsByDateStatus[$d].etihad_expected
  $ey_dep = $flightsByDateStatus[$d].etihad_departed
  
  $historyLines += "    { ""date"": ""$d"", ""emirates_expected"": $ek_exp, ""emirates_departed"": $ek_dep, ""qatar_expected"": $qr_exp, ""qatar_departed"": $qr_dep, ""etihad_expected"": $ey_exp, ""etihad_departed"": $ey_dep }"
  Write-Host "  $d : EK=$($ek_exp+$ek_dep) (exp:$ek_exp dep:$ek_dep) QR=$($qr_exp+$qr_dep) (exp:$qr_exp dep:$qr_dep) EY=$($ey_exp+$ey_dep) (exp:$ey_exp dep:$ey_dep)"
}
$historyArray = "[`n" + ($historyLines -join ",`n") + "`n  ]"

$json = @"
{
  "lastScan": "$timestamp",
  "scanVersion": 4,
  "dataNote": "Live flight data from AeroDataBox API. 6-day window (today through day 5) captured in 12 × 12h windows. Status: Expected vs Departed. Scans every 12h (2x/day).",
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
Write-Host "`nDone - 6-day scan with status tracking"

# Git push
Set-Location $RepoPath
git remote set-url origin "https://${GithubUser}:${GithubToken}@github.com/${GithubUser}/${RepoName}.git"
git add data/scan_results.json
git commit -m "scan: 6-day window with Expected/Departed status tracking $timestamp"
git push origin main
git remote set-url origin "https://github.com/${GithubUser}/${RepoName}.git"
Write-Host "Pushed to GitHub."
