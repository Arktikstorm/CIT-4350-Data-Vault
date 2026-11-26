\# SDG 14 Hudson River Water Quality Database — Design Document



\*\*Single source of truth\*\* for this project: topic selection, project definition,

data sources, schema, data dictionary, normalization, and relationships.

Consolidated from the earlier project plan, guidance notes, key-terms sheet, and

status report (now moved to `documents/archive/`).



\*\*Course:\*\* CIT 4350 · \*\*SDG:\*\* Goal 14 — Life Below Water



\## Contents



1\. \[Topic selection](#1-topic-selection)

2\. \[Project definition — overall](#2-project-definition--overall)

3\. \[Project definition — data](#3-project-definition--data)

4\. \[ER diagram](#4-er-diagram)

5\. \[Data dictionary](#5-data-dictionary)

6\. \[Normalization](#6-normalization)

7\. \[Required relationships](#7-required-relationships)

8\. \[Design decisions \& rationale](#8-design-decisions--rationale)

9\. \[Contributors](#9-contributors)



\---



\## 1. Topic selection



\*\*SDG chosen:\*\* Goal 14 — \*Life Below Water.\*



We are building a relational database for a water-based drone that monitors water

quality and microplastic pollution in the Hudson River near Newburgh, NY. SDG 14

targets marine pollution, ocean acidification, and the health of aquatic

ecosystems. A local river feeding into the Atlantic is a concrete, measurable

place to study those same pressures. The drone travels a fixed route, stops every

quarter mile to log sensor readings, and collects a water sample for lab analysis,

giving us both live chemistry data and physical microplastic counts.



\---



\## 2. Project definition — overall



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



\---



\## 3. Project definition — data



\### 3.1 Where the data comes from

\- \*\*Water drone\*\* on a fixed Hudson route near Newburgh, stopping every quarter

&#x20; mile to record a reading and draw a sample.

\- \*\*Onboard sensor array\*\* logging operational status, GPS coordinates, water

&#x20; chemistry (temperature, pH, dissolved oxygen, turbidity, salinity, flow rate),

&#x20; and a categorical hazard flag.

\- \*\*Lab spectrometer\*\* analyzing each returned bottle for microplastic

&#x20; concentration and dominant polymer types.

\- \_(Optional expansion)\_ stationary buoy sensors at 3–5 fixed points for

&#x20; continuous monitoring between drone runs.



\### 3.2 Two data feeds

Data arrives from two sources at different times, which is why `reading` (captured

instantly in the field) and `water\_sample` (analyzed in the lab days later) are

separate tables — see \[§8](#8-design-decisions--rationale).



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



\*\*Lab spectrometer results (JSON), returned after the bottle is analyzed:\*\*

```json

{

&#x20; "sample\_bottle": "B-0002",

&#x20; "reading\_id": 2,

&#x20; "collected\_at": "2026-09-19T15:54:00-04:00",

&#x20; "analyzed\_at": "2026-09-21T09:00:00-04:00",

&#x20; "volume\_l": 1.00,

&#x20; "detections": \[

&#x20;   { "polymer": "PE",  "particle\_count": 37, "absorbance": 0.21110693, "wavelength\_nm": 1215.0 },

&#x20;   { "polymer": "PP",  "particle\_count": 19, "absorbance": 0.06556157, "wavelength\_nm": 1680.0 },

&#x20;   { "polymer": "PET", "particle\_count": 24, "absorbance": 0.17872099, "wavelength\_nm": 1660.0 },

&#x20;   { "polymer": "PS",  "particle\_count":  7, "absorbance": 0.16220225, "wavelength\_nm": 1690.0 },

&#x20;   { "polymer": "PVC", "particle\_count":  4, "absorbance": 0.25552531, "wavelength\_nm": 1715.0 }

&#x20; ]

}

```



\### 3.3 How the feeds map to the schema

| Source field | Table.column |

| --- | --- |

| `run\_id`, `point\_label` | `reading.run\_id`, `sampling\_point.point\_label` |

| `gps.lat` / `gps.lon` | `reading.latitude` / `reading.longitude` (actual GPS) |

| `status` | `reading.status\_id` → `operational\_status.status\_code` |

| `sensors.\*` | `reading.water\_temp\_f`, `ph`, `dissolved\_oxygen\_mgl`, … |

| `hazard\_flag` | `reading.hazard\_flag` |

| `sample\_bottle`, `collected\_at`, `volume\_l`, `analyzed\_at` | `water\_sample.\*` |

| `detections\[]` (`polymer`, `particle\_count`, …) | `sample\_detection` (one row per sample × polymer) |



\### 3.4 Real-world data habits

\- \*\*Sensor faults:\*\* store `NULL`, never a made-up number, and record the fault in

&#x20; `status\_id` (`SENSOR\_FAULT`). Averages then skip the missing value.

\- \*\*Missing samples:\*\* a bottle can jam, so a `reading` may have no `water\_sample`.

\- \*\*Calibration/detection limits:\*\* pH and DO probes drift; the spectrometer has a

&#x20; smallest detectable particle size (microplastics are < 5 mm).



\---



\## 4. ER diagram



The single authoritative diagram is \[`diagrams/ER\_Diagram\_SDG14.png`](../diagrams/ER\_Diagram\_SDG14.png).

It matches the schema in `sql-files/SDG14\_create\_tables.sql` and the dictionary in

\[§5](#5-data-dictionary).



\---



\## 5. Data dictionary



Describes every table and column in `sql-files/SDG14\_create\_tables.sql`.



\*\*Conventions\*\*



\- \*\*Null?\*\* "No" means the column is `NOT NULL` (a value is required).

\- \*\*Keys:\*\* PK = primary key, FK = foreign key, UNIQUE = no two rows may share the value.

\- \*\*Times\*\* are stored as `DATETIME` in local time (Eastern).

\- \*\*Measurements\*\* use `DECIMAL`, not `FLOAT`, so values are stored exactly.

\- \*\*A NULL measurement\*\* means the sensor failed or the value is not available yet.

&#x20; It is never replaced with a made-up number.



\### Tables at a glance



| Table | Type | One row represents |

| --- | --- | --- |

| `drone` | Core | One water drone |

| `run` | Core | One trip of a drone along the route |

| `sampling\_point` | Core | One fixed stop on the route |

| `reading` | Core | One sensor snapshot at one stop on one run |

| `water\_sample` | Core | One water bottle collected at a reading |

| `operational\_status` | Lookup | One allowed status code |

| `runoff\_source` | Lookup | One land-based pollution source |

| `polymer\_type` | Lookup | One plastic type the lab can identify |

| `sample\_detection` | Junction | One plastic type found in one sample |



\### drone

One row per water drone.



| Column | Type | Null? | Key / Rule | Description |

| --- | --- | --- | --- | --- |

| drone\_id | INT | No | PK, auto-increment | Unique ID for the drone |

| drone\_name | VARCHAR(50) | No | | Name the team uses for the drone |

| model | VARCHAR(50) | Yes | | Manufacturer model or type |

| commissioned\_date | DATE | No | | Date the drone entered service |



\### run

One complete trip of a drone along the sampling route. `drone` 1:M `run`.



| Column | Type | Null? | Key / Rule | Description |

| --- | --- | --- | --- | --- |

| run\_id | INT | No | PK, auto-increment | Unique ID for the run |

| drone\_id | INT | No | FK → drone | Drone that performed the run |

| water\_body\_name | VARCHAR(60) | No | | Water body sampled, e.g. Hudson River |

| start\_time | DATETIME | No | | When the run began |

| end\_time | DATETIME | Yes | CHECK: NULL or ≥ start\_time | When the run ended; NULL while still in progress |



\### runoff\_source

A land-based pollution source (storm drain, urban stream, marina). Pulled into its

own lookup table so a source named once is referenced by many sampling points

instead of repeating the text on each point. `runoff\_source` 1:M `sampling\_point`.



| Column | Type | Null? | Key / Rule | Description |

| --- | --- | --- | --- | --- |

| runoff\_id | INT | No | PK, auto-increment | Unique ID for the source |

| source\_name | VARCHAR(80) | No | UNIQUE | Name/description, e.g. "Waterfront storm drain outfall" |

| source\_type | VARCHAR(40) | Yes | | Category, e.g. storm drain, urban stream, marina |



\### sampling\_point

A fixed, planned stop on the route, one every quarter mile. Static reference

locations reused across every run, which is why actual per-reading GPS lives on

`reading`, not here.



| Column | Type | Null? | Key / Rule | Description |

| --- | --- | --- | --- | --- |

| point\_id | INT | No | PK, auto-increment | Unique ID for the stop |

| point\_label | VARCHAR(20) | No | UNIQUE | Short label, e.g. NB-02 |

| river\_mile | DECIMAL(5,2) | No | | Distance along the river, in miles |

| latitude | DECIMAL(9,6) | No | CHECK: −90 to 90 | Planned latitude of the stop |

| longitude | DECIMAL(9,6) | No | CHECK: −180 to 180 | Planned longitude of the stop |

| runoff\_id | INT | Yes | FK → runoff\_source | Nearest pollution source; NULL if none nearby |

| runoff\_distance\_m | INT | Yes | CHECK: ≥ 0 | Distance to that source in meters; NULL if none nearby |



\### reading

One sensor snapshot taken at one stop during one run. `run`, `sampling\_point`, and

`operational\_status` are each 1:M `reading`. Status is recorded \*\*per reading\*\*

(see \[§8](#8-design-decisions--rationale)).



| Column | Type | Null? | Key / Rule | Description |

| --- | --- | --- | --- | --- |

| reading\_id | INT | No | PK, auto-increment | Unique ID for the reading |

| run\_id | INT | No | FK → run | Run the reading belongs to |

| point\_id | INT | No | FK → sampling\_point | Stop where the reading was taken |

| status\_id | INT | No | FK → operational\_status | Drone status at the time, e.g. SENSOR\_FAULT |

| recorded\_at | DATETIME | No | | When the reading was taken |

| latitude | DECIMAL(9,6) | No | CHECK: −90 to 90 | Drone's actual GPS latitude (may differ slightly from the planned stop) |

| longitude | DECIMAL(9,6) | No | CHECK: −180 to 180 | Drone's actual GPS longitude |

| water\_temp\_f | DECIMAL(5,2) | Yes | CHECK: 32 to 100 | Water temperature in °F |

| ph | DECIMAL(4,2) | Yes | CHECK: 0 to 14 | Acidity of the water |

| dissolved\_oxygen\_mgl | DECIMAL(5,2) | Yes | CHECK: ≥ 0 | Dissolved oxygen in mg/L; below 5 is unsafe for most aquatic life |

| turbidity\_ntu | DECIMAL(6,2) | Yes | CHECK: ≥ 0 | Cloudiness of the water in NTU |

| salinity\_ppt | DECIMAL(5,2) | Yes | CHECK: ≥ 0 | Salt content in parts per thousand |

| flow\_rate\_ms | DECIMAL(5,2) | Yes | | Water speed in m/s; negative = upstream flow from the incoming tide |

| hazard\_flag | BOOLEAN | No | Default FALSE | TRUE if the drone raised an alert for unsafe conditions |



\*\*Table rule:\*\* UNIQUE (run\_id, point\_id), so a run records at most one reading per stop.



\### water\_sample

One physical water bottle collected at a reading and analyzed later by the lab.

`reading` 1:1 `water\_sample`, \*\*optional\*\*: a reading may have no sample (e.g. the

bottle jammed).



| Column | Type | Null? | Key / Rule | Description |

| --- | --- | --- | --- | --- |

| sample\_id | INT | No | PK, auto-increment | Unique ID for the sample |

| reading\_id | INT | No | FK → reading, UNIQUE | Reading the sample was taken with; UNIQUE allows at most one sample per reading |

| collected\_at | DATETIME | No | | When the bottle was filled |

| volume\_l | DECIMAL(4,2) | No | Default 1.00, CHECK: > 0 | Volume of water collected, in liters |

| analyzed\_at | DATETIME | Yes | | When the lab finished analysis; NULL until then |



\### operational\_status

Allowed status codes for a reading. A surrogate integer key keeps foreign keys in

`reading` compact, while `status\_code` stays human-readable and unique.



| Column | Type | Null? | Key / Rule | Description |

| --- | --- | --- | --- | --- |

| status\_id | INT | No | PK, auto-increment | Surrogate key, referenced by reading |

| status\_code | VARCHAR(30) | No | UNIQUE | Short code, e.g. ACTIVE\_SAMPLING |

| description | VARCHAR(150) | No | | What the code means |



\### polymer\_type

Plastic types the lab spectrometer can identify.



| Column | Type | Null? | Key / Rule | Description |

| --- | --- | --- | --- | --- |

| polymer\_id | INT | No | PK, auto-increment | Unique ID for the plastic type |

| polymer\_name | VARCHAR(60) | No | UNIQUE | Full name, e.g. Polyethylene |

| abbreviation | VARCHAR(10) | No | UNIQUE | Short form, e.g. PE |

| common\_sources | VARCHAR(120) | Yes | | Everyday products this plastic comes from |



\### sample\_detection

Junction table resolving the many-to-many relationship between `water\_sample` and

`polymer\_type`: one sample can contain several plastics, and each plastic appears

in many samples.



| Column | Type | Null? | Key / Rule | Description |

| --- | --- | --- | --- | --- |

| sample\_id | INT | No | PK (part), FK → water\_sample | Sample the plastic was found in |

| polymer\_id | INT | No | PK (part), FK → polymer\_type | Type of plastic found |

| particle\_count | INT | No | CHECK: ≥ 0 | Number of particles of this plastic in the sample |

| absorbance | DECIMAL(10,8) | Yes | | Spectrometer reading used to identify the plastic |

| wavelength\_nm | DECIMAL(6,1) | Yes | | Wavelength of that reading, in nanometers |



\*\*Table rule:\*\* the composite primary key (sample\_id, polymer\_id) means each plastic

type is recorded at most once per sample.



\---



\## 6. Normalization



Our schema follows the standard normal forms to keep the database as free as

possible of redundancy and update anomalies.



\*\*First Normal Form (1NF).\*\* Every column holds a single value. A `reading` stores

one latitude, one pH, and one turbidity value rather than cramming multiple sensor

readings into one field.



\*\*Second Normal Form (2NF).\*\* Every non-key attribute depends on the whole primary

key. This matters most for our one composite-key table, `sample\_detection`: its key

is (`sample\_id`, `polymer\_id`), and attributes like `particle\_count` and

`absorbance` describe that specific sample-and-polymer combination, not just one

half of the pair.



\*\*Third Normal Form (3NF).\*\* Repeating, non-key-dependent facts are pulled into

their own lookup tables so each descriptive detail is stored once and referenced by

ID. `drone`, `operational\_status`, `runoff\_source`, `sampling\_point`, and

`polymer\_type` each exist so that descriptions, coordinates, and common sources live

in exactly one place instead of being copied onto every row where they could drift

out of sync.



`runoff\_source` is the clearest example: several sampling points share the same

source (Quassaick Creek covers NB-01 and NB-02; the storm-drain outfall covers

NB-03, NB-04, and NB-05; the marina covers NB-06 and NB-07). Storing that name once

in `runoff\_source` and referencing it by `runoff\_id` removes the repeated text and

the update anomaly that came with it.



\### Structural choices beyond the textbook forms

\- \*\*`reading` and `water\_sample` are split 1:1 (optional)\*\* via a UNIQUE foreign key.

&#x20; A reading is captured instantly in the field; the physical sample may sit

&#x20; unanalyzed for days, and some readings produce no sample at all. See

&#x20; \[§8](#8-design-decisions--rationale).

\- \*\*`sample\_detection` is a junction table\*\* for the many-to-many between water

&#x20; samples and polymer types: one sample can contain several plastics, and the same

&#x20; polymer shows up across many samples.

\- \*\*`runoff\_distance\_m` is a stored, precomputed value\*\* on `sampling\_point`. Because

&#x20; the stops are fixed, the distance to the nearest source is a stable property of the

&#x20; point, computed once rather than re-derived on every query. Computing true nearest

&#x20; distance from raw coordinates would need spatial functions outside this course's

&#x20; scope; this is a deliberate, documented convenience, not a normalization failure

&#x20; (`runoff\_distance\_m` depends only on `point\_id`).



\### Does a single reading occur at multiple locations?

No. A reading happens at exactly one location. `reading.point\_id` is a single,

`NOT NULL` foreign key to `sampling\_point`, so every reading points to one and only

one stop. The rule `UNIQUE (run\_id, point\_id)` further guarantees a run records at

most one reading per stop.



Location is deliberately stored in two complementary places, which is the likely

source of earlier confusion:

\- \*\*`sampling\_point`\*\* holds the \*planned\* stop — its label (e.g. NB-02), river mile,

&#x20; and the coordinates the drone is supposed to visit. These are fixed and reused

&#x20; across every run.

\- \*\*`reading`\*\* holds the drone's \*actual\* GPS latitude/longitude at the moment of the

&#x20; reading, which may differ slightly from the planned point due to current or drift.



One reading, one location: identified both by the planned stop it belongs to and by

the exact GPS coordinates where the drone actually took it.



\---



\## 7. Required relationships



| Relationship | Type | Why it exists |

| --- | --- | --- |

| `drone` → `run` | one-to-many | One drone performs many runs over its service life. |

| `run` → `reading` | one-to-many | One run produces many readings (one per stop). |

| `sampling\_point` → `reading` | one-to-many | One fixed stop is visited on many runs. |

| `operational\_status` → `reading` | one-to-many | One status code applies to many readings. |

| `runoff\_source` → `sampling\_point` | one-to-many | One source is the nearest to several stops. |

| `reading` → `water\_sample` | one-to-one (optional) | Each reading may have at most one bottle. |

| `water\_sample` ↔ `polymer\_type` | \*\*many-to-many\*\* | Resolved by `sample\_detection`: one sample holds many polymers; each polymer appears in many samples. |



The rubric asks for at least one many-to-many and one one-to-many, both explained and

modeled. The many-to-many (`water\_sample` ↔ `polymer\_type`) is realized

through the `sample\_detection` junction table with a composite key; the one-to-many

relationships above are each enforced by a foreign key.



\---



\## 8. Design decisions \& rationale



Direct answers to the design questions raised in review/comment feedback.



\*\*Why is `water\_sample` a separate table if it's 1:1 with `reading`?\*\*

Because the relationship is one-to-one \*\*optional\*\* (0-or-1). A reading can exist with

no sample, such as a jammed bottle leaves a reading with nothing to analyze. Merging the two

would force `collected\_at`, `volume\_l`, and `analyzed\_at` to be NULL on every

sample-less reading, and would mix two different lifecycles in one row: the field

snapshot (instant) and the lab result (days later). `water\_sample` is also the parent

of `sample\_detection`, so detections attach cleanly to the physical bottle rather than

to the sensor reading.



\*\*Why a surrogate key for `operational\_status` instead of the code string?\*\*

`operational\_status` uses `status\_id INT` as its primary key, with `status\_code`

kept as a `UNIQUE` column. The integer key keeps the foreign key in the high-volume

`reading` table compact and avoids a wide text key propagating across the schema,

while the readable code is still available for queries and output.



\*\*Does operational status change per reading or per run?\*\*

Per reading. A drone can be `ACTIVE\_SAMPLING` at one stop, hit a `SENSOR\_FAULT` at the

next, and go `LOW\_BATTERY` later in the same run — so the status is correctly attached

to `reading`, not `run`. The mock data demonstrates this: reading 5 is `SENSOR\_FAULT`

while every other reading on that run is `ACTIVE\_SAMPLING`.



\*\*Are sampling points static, and should location be per reading?\*\*

Sampling points are static \*planned\* reference stops, reused across every run — which

is exactly why they are modeled as a dimension/lookup table rather than fixed hardware:

the drone is mobile, visits each planned point, and also collects a physical bottle

there. The \*actual\* per-reading GPS is already stored on `reading.latitude` /

`reading.longitude`, so each reading carries the real location it was taken at, while

`sampling\_point` carries the planned location used to compare the same spot across runs.



\---



\## 9. Contributors



| Team member | Focus area |

| --- | --- | --- |

| Justin Reichelt | normalization \& relationships 

| \~\~Prerit Acharya\~\~ | optional relationships \& joins

| Hendrik Vanwingerden | data types \& constraints 

| Josiah Maddicks | requirements \& schema design 





