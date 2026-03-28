\# Role: Gulf Aviation Intelligence Agent

\# Frequency: every 6h



\## Mission: Gulf Flights Watch Live

Monitor Emirates, Etihad, Qatar Airways, and Riyadh Air for service changes due to the Iran conflict.



\## Data Points to Collect (Spec 1, 2, 3)

For each flight found on official 'Travel Updates' pages or FlightRadar24:

\- Flight Number, Origin, Transit, Destination, Time.

\- Category: \[Standard] or \[Restricted/Evacuation] (Based on news keywords like 'repatriation' or 'restricted').

\- Price: Convert to USD.



\## Visualization \& UI (Spec 4, 5, 7)

\- Update `index.html` with a Tailwind CSS dashboard.

\- Title: "Gulf Flights Watch Live"

\- Features: Interactive table with filters (Date, Destination, Price).

\- Graph: Use Chart.js to show "Flight Volume vs. Date" filterable by airline.



\## Alerts (Spec 6)

\- If a new 'Evacuation' flight is detected, send an IMMEDIATE Telegram alert to the user.

\- Every 24 hours, email a PDF summary of the day's volume trends.

