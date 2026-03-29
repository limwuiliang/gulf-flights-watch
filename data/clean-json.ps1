# Read raw JSON, strip bad UTF-8, rebuild clean
$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

# Clean all destination names of garbled UTF-8
foreach ($airline in $json.airlines) {
  foreach ($flight in $airline.flights) {
    # Replace common UTF-8 corruption patterns with proper names
    $flight.destinationName = $flight.destinationName -replace '[\u00C3\u00A4\u00A3\u00B5].*', (
      switch -regex ($flight.destination) {
        'SAO' { 'São Paulo' }
        'MAD' { 'Madrid' }
        'BOG' { 'Bogotá' }
        'DUS' { 'Düsseldorf' }
        'MAA' { 'Chennai' }
        'DEL' { 'Delhi' }
        'BOM' { 'Mumbai' }
        'BKK' { 'Bangkok' }
        'SIN' { 'Singapore' }
        'HKG' { 'Hong Kong' }
        'SYD' { 'Sydney' }
        'LAX' { 'Los Angeles' }
        'JFK' { 'New York' }
        'LHR' { 'London' }
        'CDG' { 'Paris' }
        'FRA' { 'Frankfurt' }
        'AMS' { 'Amsterdam' }
        'IST' { 'Istanbul' }
        'CAI' { 'Cairo' }
        'DXB' { 'Dubai' }
        'DOH' { 'Doha' }
        'AUH' { 'Abu Dhabi' }
        'KUL' { 'Kuala Lumpur' }
        'BKI' { 'Kota Kinabalu' }
        'JED' { 'Jeddah' }
        'RUH' { 'Riyadh' }
        default { $flight.destinationName }
      }
    )
  }
}

# Write clean JSON with UTF-8 (no BOM)
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)

Write-Host "Cleaned UTF-8 corruption in destination names"
