# SDG 14 Hudson River Water Quality Database — Design Document

**Single source of truth** for this project: topic selection, project definition,
data sources, schema, data dictionary, normalization, and relationships.
Consolidated from the earlier project plan, guidance notes, key-terms sheet, and
status report (now moved to `documents/archive/`).

**Course:** CIT 4350 · **SDG:** Goal 14 — Life Below Water

## Contents

1. [Topic selection](#1-topic-selection)
2. [Project definition — overall](#2-project-definition--overall)
3. [Project definition — data](#3-project-definition--data)
4. [ER diagram](#4-er-diagram)
5. [Data dictionary](#5-data-dictionary)
6. [Normalization](#6-normalization)
7. [Required relationships](#7-required-relationships)
8. [DBMS justification](#8-dbms-justification)
9. [Design decisions & rationale](#9-design-decisions--rationale)
10. [Contributors](#10-contributors)

---

## 1. Topic selection

**SDG chosen:** Goal 14 — *Life Below Water.*

We are building a relational database for a water-based drone that monitors water
quality and microplastic pollution in the Hudson River near Newburgh, NY. SDG 14
targets marine pollution, ocean acidification, and the health of aquatic
ecosystems. A local river feeding into the Atlantic is a concrete, measurable
place to study those same pressures. The drone travels a fixed route, stops every
quarter mile to log sensor readings, and collects a water sample for lab analysis,
giving us both live chemistry data and physical microplastic counts.

---

## 2. Project definition — overall

### Primary question
What levels of plastic pollution, chemical markers, and pH (acidity) exist in the
Hudson River near Newburgh, and how do these compare to the marine pollution and
ocean acidification trends described in SDG 14?

### Sub-questions
Each maps to a measurable column and a SQL query in `sql-files/SDG14_queries.sql`.

1. **Microplastics (SDG 14.1).** What concentration of microplastic particles
   exists per liter of river water at different points, and how does that compare
   to the ~13,000 pieces of plastic litter found per square kilometer of open
   ocean? → `SUM(particle_count) / volume_l`
2. **Acidification (SDG 14.3).** What is the pH at different points, and is it
   trending more acidic, mirroring the ~30% rise in ocean acidification seen
   globally since the industrial revolution? → average pH per run.
3. **Ecosystem health (SDG 14.2).** How do dissolved-oxygen levels compare to the
   level considered safe for aquatic life (below ~5 mg/L is unsafe)?
4. **Land-based sources (SDG 14.1).** Are pollutant levels correlated with
   proximity to industrial or urban runoff points, which the UN identifies as the
   primary source of marine pollution? → readings near vs. away from runoff.

---

## 3. Project definition — data

### 3.1 Where the data comes from
- **Water drone** on a fixed Hudson route near Newburgh, stopping every quarter
  mile to record a reading and draw a sample.
- **Onboard sensor array** logging operational status, GPS coordinates, water
  chemistry (temperature, pH, dissolved oxygen, turbidity, salinity, flow rate),
  and a categorical hazard flag.
- **Lab spectrometer** analyzing each returned bottle for microplastic
  concentration and dominant polymer types.
- _(Optional expansion)_ stationary buoy sensors at 3–5 fixed points for
  continuous monitoring between drone runs.

### 3.2 Two data feeds
Data arrives from two sources at different times, which is why `reading` (captured
instantly in the field) and `water_sample` (analyzed in the lab days later) are
separate tables — see [§8](#9-design-decisions--rationale).

**Drone telemetry packet (JSON), sent at every stop:**
```json
{
  "run_id": 1,
  "point_label": "NB-02",
  "timestamp": "2026-09-19T15:52:00-04:00",
  "gps": { "lat": 41.499713, "lon": -73.992525 },
  "status": "ACTIVE_SAMPLING",
  "sensors": {
    "water_temp_f": 69.27, "ph": 7.51, "dissolved_oxygen_mgl": 5.73,
    "turbidity_ntu": 34.71, "salinity_ppt": 2.96, "flow_rate_ms": -0.41
  },
  "hazard_flag": false,
  "sample_bottle": "B-0002"
}
```

**Lab spectrometer results (JSON), returned after the bottle is analyzed:**
```json
{
  "sample_bottle": "B-0002",
  "reading_id": 2,
  "collected_at": "2026-09-19T15:54:00-04:00",
  "analyzed_at": "2026-09-21T09:00:00-04:00",
  "volume_l": 1.00,
  "detections": [
    { "polymer": "PE",  "particle_count": 37, "absorbance": 0.21110693, "wavelength_nm": 1215.0 },
    { "polymer": "PP",  "particle_count": 19, "absorbance": 0.06556157, "wavelength_nm": 1680.0 },
    { "polymer": "PET", "particle_count": 24, "absorbance": 0.17872099, "wavelength_nm": 1660.0 },
    { "polymer": "PS",  "particle_count":  7, "absorbance": 0.16220225, "wavelength_nm": 1690.0 },
    { "polymer": "PVC", "particle_count":  4, "absorbance": 0.25552531, "wavelength_nm": 1715.0 }
  ]
}
```

### 3.3 How the feeds map to the schema
| Source field | Table.column |
| --- | --- |
| `run_id`, `point_label` | `reading.run_id`, `sampling_point.point_label` |
| `gps.lat` / `gps.lon` | `reading.latitude` / `reading.longitude` (actual GPS) |
| `status` | `reading.status_id` → `operational_status.status_code` |
| `sensors.*` | `reading.water_temp_f`, `ph`, `dissolved_oxygen_mgl`, … |
| `hazard_flag` | `reading.hazard_flag` |
| `sample_bottle`, `collected_at`, `volume_l`, `analyzed_at` | `water_sample.*` |
| `detections[]` (`polymer`, `particle_count`, …) | `sample_detection` (one row per sample × polymer) |

### 3.4 Real-world data habits
- **Sensor faults:** store `NULL`, never a made-up number, and record the fault in
  `status_id` (`SENSOR_FAULT`). Averages then skip the missing value.
- **Missing samples:** a bottle can jam, so a `reading` may have no `water_sample`.
- **Calibration/detection limits:** pH and DO probes drift; the spectrometer has a
  smallest detectable particle size (microplastics are < 5 mm).

---

## 4. ER diagram

The single authoritative diagram is [`diagrams/ER_Diagram_SDG14.png`](../diagrams/ER_Diagram_SDG14.png).
It matches the schema in `sql-files/SDG14_create_tables.sql` and the dictionary in
[§5](#5-data-dictionary).

---

## 5. Data dictionary

Describes every table and column in `sql-files/SDG14_create_tables.sql`.

**Conventions**

- **Null?** "No" means the column is `NOT NULL` (a value is required).
- **Keys:** PK = primary key, FK = foreign key, UNIQUE = no two rows may share the value.
- **Times** are stored as `DATETIME` in local time (Eastern).
- **Measurements** use `DECIMAL`, not `FLOAT`, so values are stored exactly.
- **A NULL measurement** means the sensor failed or the value is not available yet.
  It is never replaced with a made-up number.

### Tables at a glance

| Table | Type | One row represents |
| --- | --- | --- |
| `drone` | Core | One water drone |
| `run` | Core | One trip of a drone along the route |
| `sampling_point` | Core | One fixed stop on the route |
| `reading` | Core | One sensor snapshot at one stop on one run |
| `water_sample` | Core | One water bottle collected at a reading |
| `operational_status` | Lookup | One allowed status code |
| `runoff_source` | Lookup | One land-based pollution source |
| `polymer_type` | Lookup | One plastic type the lab can identify |
| `sample_detection` | Junction | One plastic type found in one sample |

### drone
One row per water drone.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| drone_id | INT | No | PK, auto-increment | Unique ID for the drone |
| drone_name | VARCHAR(50) | No | | Name the team uses for the drone |
| model | VARCHAR(50) | Yes | | Manufacturer model or type |
| commissioned_date | DATE | No | | Date the drone entered service |

### run
One complete trip of a drone along the sampling route. `drone` 1:M `run`.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| run_id | INT | No | PK, auto-increment | Unique ID for the run |
| drone_id | INT | No | FK → drone | Drone that performed the run |
| water_body_name | VARCHAR(60) | No | | Water body sampled, e.g. Hudson River |
| start_time | DATETIME | No | | When the run began |
| end_time | DATETIME | Yes | CHECK: NULL or ≥ start_time | When the run ended; NULL while still in progress |

### runoff_source
A land-based pollution source (storm drain, urban stream, marina). Pulled into its
own lookup table so a source named once is referenced by many sampling points
instead of repeating the text on each point. `runoff_source` 1:M `sampling_point`.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| runoff_id | INT | No | PK, auto-increment | Unique ID for the source |
| source_name | VARCHAR(80) | No | UNIQUE | Name/description, e.g. "Waterfront storm drain outfall" |
| source_type | VARCHAR(40) | Yes | | Category, e.g. storm drain, urban stream, marina |

### sampling_point
A fixed, planned stop on the route, one every quarter mile. Static reference
locations reused across every run, which is why actual per-reading GPS lives on
`reading`, not here.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| point_id | INT | No | PK, auto-increment | Unique ID for the stop |
| point_label | VARCHAR(20) | No | UNIQUE | Short label, e.g. NB-02 |
| river_mile | DECIMAL(5,2) | No | | Distance along the river, in miles |
| latitude | DECIMAL(9,6) | No | CHECK: −90 to 90 | Planned latitude of the stop |
| longitude | DECIMAL(9,6) | No | CHECK: −180 to 180 | Planned longitude of the stop |
| runoff_id | INT | Yes | FK → runoff_source | Nearest pollution source; NULL if none nearby |
| runoff_distance_m | INT | Yes | CHECK: ≥ 0 | Distance to that source in meters; NULL if none nearby |

### reading
One sensor snapshot taken at one stop during one run. `run`, `sampling_point`, and
`operational_status` are each 1:M `reading`. Status is recorded **per reading**
(see [§8](#9-design-decisions--rationale)).

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| reading_id | INT | No | PK, auto-increment | Unique ID for the reading |
| run_id | INT | No | FK → run | Run the reading belongs to |
| point_id | INT | No | FK → sampling_point | Stop where the reading was taken |
| status_id | INT | No | FK → operational_status | Drone status at the time, e.g. SENSOR_FAULT |
| recorded_at | DATETIME | No | | When the reading was taken |
| latitude | DECIMAL(9,6) | No | CHECK: −90 to 90 | Drone's actual GPS latitude (may differ slightly from the planned stop) |
| longitude | DECIMAL(9,6) | No | CHECK: −180 to 180 | Drone's actual GPS longitude |
| water_temp_f | DECIMAL(5,2) | Yes | CHECK: 32 to 100 | Water temperature in °F |
| ph | DECIMAL(4,2) | Yes | CHECK: 0 to 14 | Acidity of the water |
| dissolved_oxygen_mgl | DECIMAL(5,2) | Yes | CHECK: ≥ 0 | Dissolved oxygen in mg/L; below 5 is unsafe for most aquatic life |
| turbidity_ntu | DECIMAL(6,2) | Yes | CHECK: ≥ 0 | Cloudiness of the water in NTU |
| salinity_ppt | DECIMAL(5,2) | Yes | CHECK: ≥ 0 | Salt content in parts per thousand |
| flow_rate_ms | DECIMAL(5,2) | Yes | | Water speed in m/s; negative = upstream flow from the incoming tide |
| hazard_flag | BOOLEAN | No | Default FALSE | TRUE if the drone raised an alert for unsafe conditions |

**Table rule:** UNIQUE (run_id, point_id), so a run records at most one reading per stop.

### water_sample
One physical water bottle collected at a reading and analyzed later by the lab.
`reading` 1:1 `water_sample`, **optional**: a reading may have no sample (e.g. the
bottle jammed).

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| sample_id | INT | No | PK, auto-increment | Unique ID for the sample |
| reading_id | INT | No | FK → reading, UNIQUE | Reading the sample was taken with; UNIQUE allows at most one sample per reading |
| collected_at | DATETIME | No | | When the bottle was filled |
| volume_l | DECIMAL(4,2) | No | Default 1.00, CHECK: > 0 | Volume of water collected, in liters |
| analyzed_at | DATETIME | Yes | | When the lab finished analysis; NULL until then |

### operational_status
Allowed status codes for a reading. A surrogate integer key keeps foreign keys in
`reading` compact, while `status_code` stays human-readable and unique.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| status_id | INT | No | PK, auto-increment | Surrogate key, referenced by reading |
| status_code | VARCHAR(30) | No | UNIQUE | Short code, e.g. ACTIVE_SAMPLING |
| description | VARCHAR(150) | No | | What the code means |

### polymer_type
Plastic types the lab spectrometer can identify.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| polymer_id | INT | No | PK, auto-increment | Unique ID for the plastic type |
| polymer_name | VARCHAR(60) | No | UNIQUE | Full name, e.g. Polyethylene |
| abbreviation | VARCHAR(10) | No | UNIQUE | Short form, e.g. PE |
| common_sources | VARCHAR(120) | Yes | | Everyday products this plastic comes from |

### sample_detection
Junction table resolving the many-to-many relationship between `water_sample` and
`polymer_type`: one sample can contain several plastics, and each plastic appears
in many samples.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| sample_id | INT | No | PK (part), FK → water_sample | Sample the plastic was found in |
| polymer_id | INT | No | PK (part), FK → polymer_type | Type of plastic found |
| particle_count | INT | No | CHECK: ≥ 0 | Number of particles of this plastic in the sample |
| absorbance | DECIMAL(10,8) | Yes | | Spectrometer reading used to identify the plastic |
| wavelength_nm | DECIMAL(6,1) | Yes | | Wavelength of that reading, in nanometers |

**Table rule:** the composite primary key (sample_id, polymer_id) means each plastic
type is recorded at most once per sample.

---

## 6. Normalization

Our schema follows the standard normal forms to keep the database as free as
possible of redundancy and update anomalies.

**First Normal Form (1NF).** Every column holds a single value. A `reading` stores
one latitude, one pH, and one turbidity value rather than cramming multiple sensor
readings into one field.

**Second Normal Form (2NF).** Every non-key attribute depends on the whole primary
key. This matters most for our one composite-key table, `sample_detection`: its key
is (`sample_id`, `polymer_id`), and attributes like `particle_count` and
`absorbance` describe that specific sample-and-polymer combination, not just one
half of the pair.

**Third Normal Form (3NF).** Repeating, non-key-dependent facts are pulled into
their own lookup tables so each descriptive detail is stored once and referenced by
ID. `drone`, `operational_status`, `runoff_source`, `sampling_point`, and
`polymer_type` each exist so that descriptions, coordinates, and common sources live
in exactly one place instead of being copied onto every row where they could drift
out of sync.

`runoff_source` is the clearest example: several sampling points share the same
source (Quassaick Creek covers NB-01 and NB-02; the storm-drain outfall covers
NB-03, NB-04, and NB-05; the marina covers NB-06 and NB-07). Storing that name once
in `runoff_source` and referencing it by `runoff_id` removes the repeated text and
the update anomaly that came with it.

### Structural choices beyond the textbook forms
- **`reading` and `water_sample` are split 1:1 (optional)** via a UNIQUE foreign key.
  A reading is captured instantly in the field; the physical sample may sit
  unanalyzed for days, and some readings produce no sample at all. See
  [§8](#9-design-decisions--rationale).
- **`sample_detection` is a junction table** for the many-to-many between water
  samples and polymer types: one sample can contain several plastics, and the same
  polymer shows up across many samples.
- **`runoff_distance_m` is a stored, precomputed value** on `sampling_point`. Because
  the stops are fixed, the distance to the nearest source is a stable property of the
  point, computed once rather than re-derived on every query. Computing true nearest
  distance from raw coordinates would need spatial functions outside this course's
  scope; this is a deliberate, documented convenience, not a normalization failure
  (`runoff_distance_m` depends only on `point_id`).

### Does a single reading occur at multiple locations?
No. A reading happens at exactly one location. `reading.point_id` is a single,
`NOT NULL` foreign key to `sampling_point`, so every reading points to one and only
one stop. The rule `UNIQUE (run_id, point_id)` further guarantees a run records at
most one reading per stop.

Location is deliberately stored in two complementary places, which is the likely
source of earlier confusion:
- **`sampling_point`** holds the *planned* stop — its label (e.g. NB-02), river mile,
  and the coordinates the drone is supposed to visit. These are fixed and reused
  across every run.
- **`reading`** holds the drone's *actual* GPS latitude/longitude at the moment of the
  reading, which may differ slightly from the planned point due to current or drift.

One reading, one location: identified both by the planned stop it belongs to and by
the exact GPS coordinates where the drone actually took it.

---

## 7. Required relationships

| Relationship | Type | Why it exists |
| --- | --- | --- |
| `drone` → `run` | one-to-many | One drone performs many runs over its service life. |
| `run` → `reading` | one-to-many | One run produces many readings (one per stop). |
| `sampling_point` → `reading` | one-to-many | One fixed stop is visited on many runs. |
| `operational_status` → `reading` | one-to-many | One status code applies to many readings. |
| `runoff_source` → `sampling_point` | one-to-many | One source is the nearest to several stops. |
| `reading` → `water_sample` | one-to-one (optional) | Each reading may have at most one bottle. |
| `water_sample` ↔ `polymer_type` | **many-to-many** | Resolved by `sample_detection`: one sample holds many polymers; each polymer appears in many samples. |

The rubric asks for at least one many-to-many and one one-to-many, both justified and
properly modeled. The many-to-many (`water_sample` ↔ `polymer_type`) is realized
through the `sample_detection` junction table with a composite key; the one-to-many
relationships above are each enforced by a foreign key.

---

## 8. DBMS justification

**We chose MySQL 8.**

Our data is highly structured, every table has a fixed set of columns and
defined relationships, so a relational DBMS fits better than a document
or key-value store. MySQL 8.0.16 and later enforce `CHECK` constraints, which we
rely on to reject impossible readings such as a pH above 14, a negative particle
count, or an `end_time` earlier than its `start_time`.

MySQL gives us everything the project needs: exact `DECIMAL` types for coordinates
and measurements (no floating-point rounding), `AUTO_INCREMENT` surrogate keys,
foreign keys with referential integrity, and the `JOIN` / `GROUP BY` / `HAVING`
queries behind every sub-question. It is free, thoroughly documented, and runs on
every team member's workstation.

### Alternatives considered
- **PostgreSQL** — equally capable, and the better choice if we later add true
  geographic queries (e.g. computing nearest-runoff distance directly from
  coordinates with PostGIS).
- **SQLite** — simple and serverless, but weaker type enforcement and no shared
  server for a team project.
- **Microsoft Access** — useful only as an optional backup copy of the mock data,
  not as the primary engine.

---

## 9. Design decisions & rationale

Direct answers to the design questions raised in review.

**Why is `water_sample` a separate table if it's 1:1 with `reading`?**
Because the relationship is one-to-one **optional** (0-or-1). A reading can exist with
no sample — a jammed bottle leaves a reading with nothing to analyze. Merging the two
would force `collected_at`, `volume_l`, and `analyzed_at` to be NULL on every
sample-less reading, and would mix two different lifecycles in one row: the field
snapshot (instant) and the lab result (days later). `water_sample` is also the parent
of `sample_detection`, so detections attach cleanly to the physical bottle rather than
to the sensor reading.

**Why a surrogate key for `operational_status` instead of the code string?**
`operational_status` uses `status_id INT` as its primary key, with `status_code`
kept as a `UNIQUE` column. The integer key keeps the foreign key in the high-volume
`reading` table compact and avoids a wide text key propagating across the schema,
while the readable code is still available for queries and output.

**Does operational status change per reading or per run?**
Per reading. A drone can be `ACTIVE_SAMPLING` at one stop, hit a `SENSOR_FAULT` at the
next, and go `LOW_BATTERY` later in the same run — so the status is correctly attached
to `reading`, not `run`. The mock data demonstrates this: reading 5 is `SENSOR_FAULT`
while every other reading on that run is `ACTIVE_SAMPLING`.

**Are sampling points static, and should location be per reading?**
Sampling points are static *planned* reference stops, reused across every run — which
is exactly why they are modeled as a dimension/lookup table rather than fixed hardware:
the drone is mobile, visits each planned point, and also collects a physical bottle
there. The *actual* per-reading GPS is already stored on `reading.latitude` /
`reading.longitude`, so each reading carries the real location it was taken at, while
`sampling_point` carries the planned location used to compare the same spot across runs.

---

## 10. Contributors

| Team member | Focus area | Git identities seen in history |
| --- | --- | --- |
| Justin Reichelt | normalization & relationships |
| ~~Prerit Acharya~~ | optional relationships & joins | 
| Hendrik Vanwingerden | data types & constraints |
| Josiah Maddicks | requirements & schema design | 




