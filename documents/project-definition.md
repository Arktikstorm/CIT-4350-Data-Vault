\# Project Definition — SDG 14 Hudson River Water Quality Database



Single source of truth for topic selection and project scope. Consolidated from

the project plan, guidance notes, and status report.



\## 1. Topic selection



\*\*SDG chosen:\*\* Goal 14 — \*Life Below Water.\*



We are building a relational database for a water-based drone that monitors water

quality and microplastic pollution in the Hudson River near Newburgh, NY. SDG 14

targets marine pollution, ocean acidification, and the health of aquatic

ecosystems, a local river feeding into the Atlantic is a concrete, measurable

place to study those same pressures. The drone travels a fixed route, stops every

quarter mile to log sensor readings, and collects a water sample for lab analysis,

giving us both live chemistry data and physical microplastic counts.



\## 2. Project definition (overall)



\### Primary question

What levels of plastic pollution, chemical markers, and pH (acidity) exist in the

Hudson River near Newburgh, and how do these compare to the marine pollution and

ocean acidification trends described in SDG 14?



\### Sub-questions

Each maps to a measurable column and a SQL query in `sql-files/SDG14\_queries.sql`.



1\. \*\*Microplastics (SDG 14.1).\*\* What concentration of microplastic particles

&#x20;  exists per liter of river water at different points, and how does that compare

&#x20;  to the \~13,000 pieces of plastic litter found per square kilometer of open

&#x20;  ocean? → `SUM(particle\_count) / volume\_l`

2\. \*\*Acidification (SDG 14.3).\*\* What is the pH at different points, and is it

&#x20;  trending more acidic, mirroring the \~30% rise in ocean acidification seen

&#x20;  globally since the industrial revolution? → average pH per run.

3\. \*\*Ecosystem health (SDG 14.2).\*\* How do dissolved-oxygen levels compare to the

&#x20;  level considered safe for aquatic life (below \~5 mg/L is unsafe)?

4\. \*\*Land-based sources (SDG 14.1).\*\* Are pollutant levels correlated with

&#x20;  proximity to industrial or urban runoff points, which the UN identifies as the

&#x20;  primary source of marine pollution? → readings near vs. away from runoff.



\## 3. Project definition — data



\### 3.1 Where the data comes from

\- \*\*Water drone\*\* on a fixed Hudson route near Newburgh, stopping every quarter

&#x20; mile to record a reading and draw a sample.

\- \*\*Onboard sensor array\*\* logging operational status, GPS coordinates, water

&#x20; chemistry (temperature, pH, dissolved oxygen, turbidity, salinity, flow rate),

&#x20; and a categorical hazard flag.

\- \*\*Lab spectrometer\*\* analyzing each returned bottle for microplastic

&#x20; concentration and dominant polymer types.



\### 3.2 Two data feeds

Data arrives from two sources at different times, which is why `Reading` (captured

instantly in the field) and `WaterSample` (analyzed in the lab days later) are

separate tables.



\*\*Drone telemetry packet (JSON), sent at every stop:\*\*

```json

{

&#x20; "run\_id": 1,

&#x20; "point\_label": "NB-02",

&#x20; "timestamp": "2026-09-19T15:52:00-04:00",

&#x20; "gps": { "lat": 41.499713, "lon": -73.992525 },

&#x20; "status": "ACTIVE\_SAMPLING",

&#x20; "sensors": {

&#x20;   "water\_temp\_f": 69.27, "ph": 7.51, "dissolved\_oxygen\_mgl": 5.73,

&#x20;   "turbidity\_ntu": 34.71, "salinity\_ppt": 2.96, "flow\_rate\_ms": -0.41

&#x20; },

&#x20; "hazard\_flag": false,

&#x20; "sample\_bottle": "B-0002"

}
```



\*\*Lab spectrometer results, returned after analysis:\*\*

