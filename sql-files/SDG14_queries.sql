-- =====================================================================
-- SDG 14 Hudson River Water Quality Database
-- 03_queries.sql  |  run after SDG14_create_tables.sql and SDG14_insert_mock_data.sql
--
-- Each query answers (part of) one of our project questions:
--   Question 1  Microplastic concentration per point   -> Q1, Q2   (SDG 14.1)
--   Question 2  pH per point / change between runs     -> Q3       (SDG 14.3)
--   Question 3  Dissolved oxygen below the safe level  -> Q4       (SDG 14.2)
--   Question 4  Pollution near vs. away from runoff    -> Q5, Q7   (SDG 14.1)
--   Data quality                                       -> Q6, Q8
-- =====================================================================

USE sdg14_hudson;

-- ---------------------------------------------------------------------
-- Q1. Microplastic concentration (particles per litre) at each point, per run.
-- Question 1. Total particles are calculated with SUM() over the junction
-- table (not stored) and divided by the bottle volume, so a bottle that is
-- not exactly 1 L is still handled correctly.
-- ---------------------------------------------------------------------
SELECT r.run_id,
       sp.point_label,
       sp.nearest_runoff_source,
       SUM(sd.particle_count)                         AS total_particles,
       ROUND(SUM(sd.particle_count) / ws.volume_l, 1) AS particles_per_l
FROM SampleDetection sd
JOIN WaterSample   ws ON ws.sample_id = sd.sample_id
JOIN Reading       r  ON r.reading_id = ws.reading_id
JOIN SamplingPoint sp ON sp.point_id  = r.point_id
GROUP BY r.run_id, sp.point_label, sp.nearest_runoff_source, ws.sample_id, ws.volume_l
ORDER BY particles_per_l DESC, r.run_id;

-- ---------------------------------------------------------------------
-- Q2. Which plastic types dominate? (the many-to-many relationship in use)
-- Question 1. Groups the junction rows by polymer; the subquery gives the
-- grand total so each polymer's share can be shown as a percentage.
-- Polymer type points to likely sources (e.g. PE = bags and film).
-- ---------------------------------------------------------------------
SELECT pt.abbreviation,
       pt.polymer_name,
       SUM(sd.particle_count) AS particles,
       ROUND(100.0 * SUM(sd.particle_count) /
             (SELECT SUM(particle_count) FROM SampleDetection), 1) AS pct_of_total
FROM SampleDetection sd
JOIN PolymerType pt ON pt.polymer_id = sd.polymer_id
GROUP BY pt.abbreviation, pt.polymer_name
ORDER BY particles DESC;

-- ---------------------------------------------------------------------
-- Q3. Average, minimum and maximum pH per run.
-- Question 2. Comparing runs over time shows whether the river is becoming
-- more acidic. COUNT(r.ph) shows how many readings were used (NULLs from
-- failed sensors are skipped). Two runs cannot prove a trend; the query is
-- built to work the same way once months of runs exist.
-- ---------------------------------------------------------------------
SELECT ru.run_id,
       DATE(ru.start_time) AS run_date,
       ROUND(AVG(r.ph), 2) AS avg_ph,
       MIN(r.ph)           AS min_ph,
       MAX(r.ph)           AS max_ph,
       COUNT(r.ph)         AS readings_used
FROM Run ru
JOIN Reading r ON r.run_id = ru.run_id
GROUP BY ru.run_id, DATE(ru.start_time)
ORDER BY run_date;

-- ---------------------------------------------------------------------
-- Q4. Readings where dissolved oxygen fell below 5 mg/L.
-- Question 3. 5 mg/L is the commonly used minimum for healthy aquatic life.
-- Uses idx_reading_do. hazard_flag is shown so we can confirm the drone's
-- field alert agrees with the stored value.
-- ---------------------------------------------------------------------
SELECT sp.point_label,
       r.recorded_at,
       r.dissolved_oxygen_mgl,
       r.hazard_flag
FROM Reading r
JOIN SamplingPoint sp ON sp.point_id = r.point_id
WHERE r.dissolved_oxygen_mgl < 5
ORDER BY r.dissolved_oxygen_mgl;

-- ---------------------------------------------------------------------
-- Q5. Near runoff (<= 500 m) versus away from runoff.
-- Question 4. The subquery calculates particles per litre for each sample;
-- CASE sorts each sampling point into a group; the outer query compares
-- average plastic, turbidity and oxygen. Points with no runoff source
-- (NULL distance) fall into the "away" group.
-- This shows association, not proof of cause.
-- ---------------------------------------------------------------------
SELECT CASE WHEN sp.runoff_distance_m <= 500 THEN 'Near runoff (<= 500 m)'
            ELSE 'Away from runoff (> 500 m)' END AS location_group,
       COUNT(*)                              AS samples,
       ROUND(AVG(x.particles_per_l), 1)      AS avg_particles_per_l,
       ROUND(AVG(r.turbidity_ntu), 1)        AS avg_turbidity_ntu,
       ROUND(AVG(r.dissolved_oxygen_mgl), 2) AS avg_do_mgl
FROM (SELECT ws.sample_id, ws.reading_id,
             SUM(sd.particle_count) / ws.volume_l AS particles_per_l
      FROM WaterSample ws
      JOIN SampleDetection sd ON sd.sample_id = ws.sample_id
      GROUP BY ws.sample_id, ws.reading_id, ws.volume_l) x
JOIN Reading r        ON r.reading_id = x.reading_id
JOIN SamplingPoint sp ON sp.point_id  = r.point_id
GROUP BY CASE WHEN sp.runoff_distance_m <= 500 THEN 'Near runoff (<= 500 m)'
              ELSE 'Away from runoff (> 500 m)' END;

-- ---------------------------------------------------------------------
-- Q6. Data-quality check: readings with no water sample.
-- LEFT JOIN keeps every reading; WHERE ... IS NULL keeps only the ones
-- with no matching sample (the optional side of the 1:1 relationship).
-- ---------------------------------------------------------------------
SELECT r.reading_id,
       ru.run_id,
       sp.point_label,
       r.recorded_at
FROM Reading r
JOIN Run ru           ON ru.run_id   = r.run_id
JOIN SamplingPoint sp ON sp.point_id = r.point_id
LEFT JOIN WaterSample ws ON ws.reading_id = r.reading_id
WHERE ws.sample_id IS NULL;

-- ---------------------------------------------------------------------
-- Q7. Sampling points whose average exceeds 50 particles per litre.
-- Question 4. HAVING filters on the aggregated value (WHERE cannot).
-- Lists the "hot spots" to compare against their runoff sources.
-- ---------------------------------------------------------------------
SELECT sp.point_label,
       sp.nearest_runoff_source,
       ROUND(AVG(x.particles_per_l), 1) AS avg_particles_per_l
FROM (SELECT ws.reading_id,
             SUM(sd.particle_count) / ws.volume_l AS particles_per_l
      FROM WaterSample ws
      JOIN SampleDetection sd ON sd.sample_id = ws.sample_id
      GROUP BY ws.sample_id, ws.reading_id, ws.volume_l) x
JOIN Reading r        ON r.reading_id = x.reading_id
JOIN SamplingPoint sp ON sp.point_id  = r.point_id
GROUP BY sp.point_label, sp.nearest_runoff_source
HAVING AVG(x.particles_per_l) > 50
ORDER BY avg_particles_per_l DESC;

-- ---------------------------------------------------------------------
-- Q8. Data-quality check: readings with a failed sensor.
-- Shows the NULL + SENSOR_FAULT approach: the bad value is missing rather
-- than made up, and the status explains why.
-- ---------------------------------------------------------------------
SELECT r.reading_id,
       sp.point_label,
       r.recorded_at,
       os.description,
       r.water_temp_f
FROM Reading r
JOIN SamplingPoint     sp ON sp.point_id    = r.point_id
JOIN OperationalStatus os ON os.status_code = r.status_code
WHERE r.status_code = 'SENSOR_FAULT';
