# Data Dictionary: SDG 14 Hudson River Water Quality Database

This dictionary describes every table and column in `sql-files/SDG14_create_tables.sql`. See the [ER diagram](../diagrams/ER_Diagram_SDG14.png) for how the tables connect.

**Conventions**

- **Null?** "No" means the column is `NOT NULL` (a value is required).
- **Keys:** PK = primary key, FK = foreign key, UNIQUE = no two rows may share the value.
- **Times** are stored as `DATETIME` in local time (Eastern).
- **Measurements** use `DECIMAL`, not `FLOAT`, so values are stored exactly.
- **A NULL measurement** means the sensor failed or the value is not available yet. It is never replaced with a made-up number.

## Tables at a glance

| Table | Type | One row represents |
| --- | --- | --- |
| Drone | Core | One water drone |
| Run | Core | One trip of a drone along the route |
| SamplingPoint | Core | One fixed stop on the route |
| Reading | Core | One sensor snapshot at one stop on one run |
| WaterSample | Core | One water bottle collected at a reading |
| OperationalStatus | Lookup | One allowed status code |
| PolymerType | Lookup | One plastic type the lab can identify |
| SampleDetection | Junction | One plastic type found in one sample |

---

## Drone

One row per water drone.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| drone_id | INT | No | PK, auto-increment | Unique ID for the drone |
| drone_name | VARCHAR(50) | No | | Name the team uses for the drone |
| model | VARCHAR(50) | Yes | | Manufacturer model or type |
| commissioned_date | DATE | No | | Date the drone entered service |

## Run

One complete trip of a drone along the sampling route. Drone 1:M Run.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| run_id | INT | No | PK, auto-increment | Unique ID for the run |
| drone_id | INT | No | FK → Drone | Drone that performed the run |
| water_body_name | VARCHAR(60) | No | | Water body sampled, e.g. Hudson River |
| start_time | DATETIME | No | | When the run began |
| end_time | DATETIME | Yes | CHECK: NULL or ≥ start_time | When the run ended; NULL while still in progress |

## SamplingPoint

A fixed stop on the route, one every quarter mile. Storing runoff information here lets readings be compared near and away from runoff sources.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| point_id | INT | No | PK, auto-increment | Unique ID for the stop |
| point_label | VARCHAR(20) | No | UNIQUE | Short label, e.g. NB-02 |
| river_mile | DECIMAL(5,2) | No | | Distance along the river, in miles |
| latitude | DECIMAL(9,6) | No | CHECK: −90 to 90 | Planned latitude of the stop |
| longitude | DECIMAL(9,6) | No | CHECK: −180 to 180 | Planned longitude of the stop |
| nearest_runoff_source | VARCHAR(80) | Yes | | Nearest pollution source, e.g. a storm drain; NULL if none nearby |
| runoff_distance_m | INT | Yes | | Distance to that source in meters; NULL if none nearby |

## Reading

One sensor snapshot taken at one stop during one run. Run, SamplingPoint and OperationalStatus are each 1:M Reading.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| reading_id | INT | No | PK, auto-increment | Unique ID for the reading |
| run_id | INT | No | FK → Run | Run the reading belongs to |
| point_id | INT | No | FK → SamplingPoint | Stop where the reading was taken |
| status_code | VARCHAR(30) | No | FK → OperationalStatus | Drone status at the time, e.g. SENSOR_FAULT |
| recorded_at | DATETIME | No | | When the reading was taken |
| latitude | DECIMAL(9,6) | No | | Drone's actual GPS latitude (may differ slightly from the planned stop) |
| longitude | DECIMAL(9,6) | No | | Drone's actual GPS longitude |
| water_temp_f | DECIMAL(5,2) | Yes | CHECK: 32 to 100 | Water temperature in °F |
| ph | DECIMAL(4,2) | Yes | CHECK: 0 to 14 | Acidity of the water |
| dissolved_oxygen_mgl | DECIMAL(5,2) | Yes | CHECK: ≥ 0 | Dissolved oxygen in mg/L; below 5 is unsafe for most aquatic life |
| turbidity_ntu | DECIMAL(6,2) | Yes | CHECK: ≥ 0 | Cloudiness of the water in NTU |
| salinity_ppt | DECIMAL(5,2) | Yes | CHECK: ≥ 0 | Salt content in parts per thousand |
| flow_rate_ms | DECIMAL(5,2) | Yes | | Water speed in m/s; negative values mean upstream flow from the incoming tide |
| hazard_flag | BOOLEAN | No | Default FALSE | TRUE if the drone raised an alert for unsafe conditions |

**Table rule:** UNIQUE (run_id, point_id), so a run records at most one reading per stop.

## WaterSample

One physical water bottle collected at a reading and analyzed later by the lab. Reading 1:1 WaterSample, optional: a reading may have no sample, for example if the bottle jammed.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| sample_id | INT | No | PK, auto-increment | Unique ID for the sample |
| reading_id | INT | No | FK → Reading, UNIQUE | Reading the sample was taken with; UNIQUE allows at most one sample per reading |
| collected_at | DATETIME | No | | When the bottle was filled |
| volume_l | DECIMAL(4,2) | No | Default 1.00, CHECK: > 0 | Volume of water collected, in liters |
| analyzed_at | DATETIME | Yes | | When the lab finished analysis; NULL until then |

## OperationalStatus

Allowed status codes for a reading. Using a lookup table prevents typos from creating false categories.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| status_code | VARCHAR(30) | No | PK | Short code, e.g. ACTIVE_SAMPLING |
| description | VARCHAR(150) | No | | What the code means |

## PolymerType

Plastic types the lab spectrometer can identify.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| polymer_id | INT | No | PK, auto-increment | Unique ID for the plastic type |
| polymer_name | VARCHAR(60) | No | UNIQUE | Full name, e.g. Polyethylene |
| abbreviation | VARCHAR(10) | No | UNIQUE | Short form, e.g. PE |
| common_sources | VARCHAR(120) | Yes | | Everyday products this plastic comes from |

## SampleDetection

Junction table resolving the many-to-many relationship between WaterSample and PolymerType: one sample can contain several plastics, and each plastic appears in many samples.

| Column | Type | Null? | Key / Rule | Description |
| --- | --- | --- | --- | --- |
| sample_id | INT | No | PK (part), FK → WaterSample | Sample the plastic was found in |
| polymer_id | INT | No | PK (part), FK → PolymerType | Type of plastic found |
| particle_count | INT | No | CHECK: ≥ 0 | Number of particles of this plastic in the sample |
| absorbance | DECIMAL(10,8) | Yes | | Spectrometer reading used to identify the plastic |
| wavelength_nm | DECIMAL(6,1) | Yes | | Wavelength of that reading, in nanometers |

**Table rule:** the composite primary key (sample_id, polymer_id) means each plastic type is recorded at most once per sample.
