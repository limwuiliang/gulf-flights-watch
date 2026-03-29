$json = Get-Content 'scan_results.json' -Raw | ConvertFrom-Json

$cityMap = @{
  'SAO' = 'São Paulo'
  'MAD' = 'Madrid'
  'BOG' = 'Bogotá'
  'DUS' = 'Düsseldorf'
  'MAA' = 'Chennai'
  'DEL' = 'Delhi'
  'BOM' = 'Mumbai'
  'BKK' = 'Bangkok'
  'SIN' = 'Singapore'
  'HKG' = 'Hong Kong'
  'SYD' = 'Sydney'
  'LAX' = 'Los Angeles'
  'JFK' = 'New York'
  'LHR' = 'London'
  'CDG' = 'Paris'
  'FRA' = 'Frankfurt'
  'AMS' = 'Amsterdam'
  'IST' = 'Istanbul'
  'CAI' = 'Cairo'
  'DXB' = 'Dubai'
  'DOH' = 'Doha'
  'AUH' = 'Abu Dhabi'
  'KUL' = 'Kuala Lumpur'
  'JED' = 'Jeddah'
  'RUH' = 'Riyadh'
}

# Clean all flights
foreach ($airline in $json.airlines) {
  foreach ($flight in $airline.flights) {
    # If destination name has non-ASCII chars or looks garbled, use cityMap
    if ($cityMap.ContainsKey($flight.destination)) {
      $flight.destinationName = $cityMap[$flight.destination]
    }
  }
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText('scan_results.json', ($json | ConvertTo-Json -Depth 10), $utf8)

Write-Host "Cleaned UTF-8 in destination names (using cityMap for IATA codes)"
