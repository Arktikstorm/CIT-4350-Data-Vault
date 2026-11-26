# Project Definition — SDG 14 Hudson River Water Quality Database

Single source of truth for topic selection and project scope. Consolidated from
the project plan, guidance notes, and status report.

## 1. Topic selection

**SDG chosen:** Goal 14 — *Life Below Water.*

We are building a relational database for a water-based drone that monitors water
quality and microplastic pollution in the Hudson River near Newburgh, NY. SDG 14
targets marine pollution, ocean acidification, and the health of aquatic
ecosystems. A local river feeding into the Atlantic is a concrete, measurable
place to study those same pressures. The drone travels a fixed route, stops every
quarter mile to log sensor readings, and collects a water sample for lab analysis,
giving us both live chemistry data and physical microplastic counts.

## 2. Project definition (overall)

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
Data arrives from two sources at different times, which is why `Reading` (captured
instantly in the field) and `WaterSample` (analyzed in the lab days later) are
separate tables.

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

**Lab spectrometer results, returned after analysis:**

### 3.3 How the feeds map to the schema
| Source field | Table.column |
| --- | --- |
| `run_id`, `point_label` | `Reading.run_id`, `SamplingPoint.point_label` |
| `gps.lat` / `gps.lon` | `Reading.latitude` / `Reading.longitude` (actual GPS) |
| `status` | `Reading.status_code` → `OperationalStatus` |
| `sensors.*` | `Reading.water_temp_f`, `ph`, `dissolved_oxygen_mgl`, … |
| `hazard_flag` | `Reading.hazard_flag` |
| `polymer`, `particle_count`, … | `SampleDetection` (per sample × polymer) |

### 3.4 Real-world data habits
- **Sensor faults:** store `NULL`, never a made-up number, and record the fault in
  `status_code`. Averages then skip the missing value.
- **Missing samples:** a bottle can jam, so a `Reading` may have no `WaterSample`.
- **Calibration/detection limits:** pH and DO probes drift; the spectrometer has a
  smallest detectable particle size (microplastics are < 5 mm).

