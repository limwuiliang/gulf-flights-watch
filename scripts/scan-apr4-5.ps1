param(
  [string]$RapidApiKey  = "YOUR_RAPIDAPI_KEY_HERE",
  [string]$GithubToken  = "YOUR_GITHUB_TOKEN_HERE"
)

$rapidHost = "aerodatabox.p.rapidapi.com"
$hdrs = @{ "x-rapidapi-host" = $rapidHost; "x-rapidapi-key" = $RapidApiKey }

# Query Apr 4 & 5 only
$datesToScan = @(
  [System.DateTime]::Parse("2026-04-04"),
  [System.DateTime]::Parse("2026-04-05")
)

$byAirline = @{ emirates=@(); qatar=@(); etihad=@() }
$flightsByDateStatus = @{}

foreach ($d in $datesToScan) {
  Write-Host "Scanning $($d.ToString('yyyy-MM-dd'))..."
  
  # 2 windows per day (00:00-12:00, 12:00-24:00)
  $windows = @(
    @{ s=$d.ToString("yyyy-MM-ddT00:00"); e=$d.AddHours(12).ToString("yyyy-MM-ddT12:00"); date=$d.ToString("yyyy-MM-dd") },
    @{ s=$d.AddHours(12).ToString("yyyy-MM-ddT12:00"); e=$d.AddDays(1).ToString("yyyy-MM-ddT00:00"); date=$d.ToString("yyyy-MM-dd") }
  )
  
  foreach ($w in $windows) {
    foreach ($ap in @("DXB", "DOH", "AUH")) {
      $id = if ($ap -eq "DXB") { "emirates" } elseif ($ap -eq "DOH") { "qatar" } else { "etihad" }
      $pfx = if ($ap -eq "DXB") { "EK" } elseif ($ap -eq "DOH") { "QR" } else { "EY" }
      
      $url = "https://aerodatabox.p.rapidapi.com/flights/airports/iata/$ap/$($w.s)/$($w.e)?direction=Departure&withLeg=true&withCancelled=false&withCodeshared=false&withCargo=false&withPrivate=false"
      
      Write-Host "  $ap $($w.s) → $($w.e)..." -NoNewline
      
      try {
        Start-Sleep -Seconds 5
        $r = Invoke-RestMethod -Uri $url -Headers $hdrs -Method Get
        $filtered = @($r.departures | Where-Object { ($_.number -replace '\s','').StartsWith($pfx) })
        Write-Host " $($filtered.Count) flights"
        
        foreach ($f in $filtered) {
          $dep = $f.departure.scheduledTime.local
          $d_str = $dep.Substring(0,10)
          $fn = ($f.number -replace '\s','')
          $status = $f.status
          
          $byAirline[$id] += [ordered]@{
            flightNumber    = $fn
            origin          = $ap
            transit         = $null
            destination     = "$($f.arrival.airport.iata)"
            destinationName = "$($f.arrival.airport.name)"
            date            = $d_str
            time            = $dep.Substring(11,5)
            status          = $status
            category        = "Standard"
            priceUSD        = $null
            note            = "Live data via AeroDataBox"
          }
          
          if (-not $flightsByDateStatus[$d_str]) {
            $flightsByDateStatus[$d_str] = @{ 
              emirates_expected = 0; emirates_departed = 0
              qatar_expected = 0; qatar_departed = 0
              etihad_expected = 0; etihad_departed = 0
            }
          }
          $statusKey = "$($id)_$($status.ToLower())"
          if ($flightsByDateStatus[$d_str][$statusKey] -ne $null) {
            $flightsByDateStatus[$d_str][$statusKey]++
          }
        }
      } catch {
        Write-Host " ERROR: $($_.Exception.Message)"
      }
    }
  }
}

Write-Host "`nFlights retrieved:"
Write-Host "  Emirates: $($byAirline.emirates.Count)"
Write-Host "  Qatar: $($byAirline.qatar.Count)"
Write-Host "  Etihad: $($byAirline.etihad.Count)"

# Load existing data
$json = Get-Content "C:\Users\wuili\gulf-flights-watch\data\scan_results.json" -Raw | ConvertFrom-Json

# Remove Apr 4 & 5 from existing flights (replace with real API data)
foreach ($airline in $json.airlines) {
  $airline.flights = @($airline.flights | Where-Object { $_.date -lt "2026-04-04" -or $_.date -gt "2026-04-05" })
}

# Add new flights
$json.airlines[0].flights += $byAirline.emirates
$json.airlines[1].flights += $byAirline.qatar
$json.airlines[2].flights += $byAirline.etihad

# Update flightVolumeHistory for Apr 4 & 5
foreach ($dateStr in @("2026-04-04", "2026-04-05")) {
  $entry = $json.flightVolumeHistory | Where-Object { $_.date -eq $dateStr }
  if ($entry) {
    $entry.emirates_scheduled = if ($flightsByDateStatus[$dateStr]) { $flightsByDateStatus[$dateStr].emirates_expected } else { 0 }
    $entry.emirates_departed = if ($flightsByDateStatus[$dateStr]) { $flightsByDateStatus[$dateStr].emirates_departed } else { 0 }
    $entry.qatar_scheduled = if ($flightsByDateStatus[$dateStr]) { $flightsByDateStatus[$dateStr].qatar_expected } else { 0 }
    $entry.qatar_departed = if ($flightsByDateStatus[$dateStr]) { $flightsByDateStatus[$dateStr].qatar_departed } else { 0 }
    $entry.etihad_scheduled = if ($flightsByDateStatus[$dateStr]) { $flightsByDateStatus[$dateStr].etihad_expected } else { 0 }
    $entry.etihad_departed = if ($flightsByDateStatus[$dateStr]) { $flightsByDateStatus[$dateStr].etihad_departed } else { 0 }
  }
}

$json.lastScan = [System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("C:\Users\wuili\gulf-flights-watch\data\scan_results.json", ($json | ConvertTo-Json -Depth 10), $utf8)

Write-Host "`nSaved to scan_results.json"

# Git commit & push
Set-Location "C:\Users\wuili\gulf-flights-watch"
git add data/scan_results.json
git commit -m "scan: Apr 4 & 5 real API data (replaced cloned flights)"
git push origin main

Write-Host "Pushed to GitHub"
