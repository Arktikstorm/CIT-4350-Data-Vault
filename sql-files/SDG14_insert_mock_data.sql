-- =====================================================================
-- SDG 14 Hudson River Water Quality Database
-- SDG14_insert_mock_data.sql  |  run after SDG14_create_tables.sql
--
-- Fictional test data: 1 drone, 2 runs (2026-09-19 and 2026-10-03),
-- 8 sampling points a quarter mile apart near Newburgh, NY,
-- 16 readings, 15 water samples, 75 polymer detections.
--
-- Built-in test cases:
--   * NB-02, NB-03, NB-04, NB-06 are within 500 m of a runoff source and
--     have more microplastics, higher turbidity and lower oxygen.
--   * Reading 5  : thermometer failed -> water_temp_f NULL, SENSOR_FAULT.
--   * Reading 11 : dissolved oxygen 4.82 mg/L -> hazard_flag TRUE.
--   * Reading 16 : bottle jammed -> no WaterSample row (found by Q6).
--   * Negative flow_rate_ms values = incoming (flood) tide.
--
-- Insert order matters: parents before children, or foreign keys fail.
-- Times are local time (EDT, UTC-4).
-- =====================================================================

USE sdg14_hudson;

-- ---------- Lookup / reference tables ----------

INSERT INTO Drone (drone_id, drone_name, model, commissioned_date) VALUES
    (1, 'HudsonScout-01', 'Autonomous surface vessel, 1.8 m', '2026-06-01');

INSERT INTO OperationalStatus (status_code, description) VALUES
    ('ACTIVE_SAMPLING', 'Stopped; sensors logging and water sample being drawn'),
    ('IN_TRANSIT',      'Moving between sampling points; sensors logging only'),
    ('SENSOR_FAULT',    'One or more sensors returned an invalid value'),
    ('LOW_BATTERY',     'Battery below 20 percent; returning to dock after this stop'),
    ('DOCKED',          'At the dock; not collecting data');

INSERT INTO SamplingPoint
    (point_id, point_label, river_mile, latitude, longitude, nearest_runoff_source, runoff_distance_m) VALUES
    (1, 'NB-01', 59.75, 41.496100, -73.992300, 'Quassaick Creek mouth (urban stream)', 650),
    (2, 'NB-02', 60.00, 41.499700, -73.992500, 'Quassaick Creek mouth (urban stream)', 120),
    (3, 'NB-03', 60.25, 41.503300, -73.992600, 'Waterfront storm drain outfall', 180),
    (4, 'NB-04', 60.50, 41.506900, -73.992800, 'Waterfront storm drain outfall', 320),
    (5, 'NB-05', 60.75, 41.510600, -73.993000, 'Waterfront storm drain outfall', 720),
    (6, 'NB-06', 61.00, 41.514200, -73.993100, 'Marina / boat launch', 150),
    (7, 'NB-07', 61.25, 41.517800, -73.993300, 'Marina / boat launch', 560),
    (8, 'NB-08', 61.50, 41.521400, -73.993400, NULL, NULL);

INSERT INTO PolymerType (polymer_id, polymer_name, abbreviation, common_sources) VALUES
    (1, 'Polyethylene',               'PE',  'Bags, film, bottles'),
    (2, 'Polypropylene',              'PP',  'Bottle caps, food containers, rope'),
    (3, 'Polyethylene terephthalate', 'PET', 'Beverage bottles, synthetic fabric'),
    (4, 'Polystyrene',                'PS',  'Foam cups, takeout containers'),
    (5, 'Polyvinyl chloride',         'PVC', 'Pipes, vinyl siding, packaging');

-- ---------- Runs ----------

INSERT INTO Run (run_id, drone_id, water_body_name, start_time, end_time) VALUES
    (1, 1, 'Hudson River', '2026-09-19 15:30:00', '2026-09-19 17:15:00'),
    (2, 1, 'Hudson River', '2026-10-03 10:00:00', '2026-10-03 11:50:00');

-- ---------- Readings (one per stop per run) ----------

INSERT INTO Reading
    (reading_id, run_id, point_id, status_code, recorded_at, latitude, longitude,
     water_temp_f, ph, dissolved_oxygen_mgl, turbidity_ntu, salinity_ppt, flow_rate_ms, hazard_flag) VALUES
    (1, 1, 1, 'ACTIVE_SAMPLING', '2026-09-19 15:40:00', 41.496113, -73.992325, 69.85, 7.84, 7.40, 12.40, 3.08, -0.45, FALSE),
    (2, 1, 2, 'ACTIVE_SAMPLING', '2026-09-19 15:52:00', 41.499713, -73.992525, 69.27, 7.51, 5.73, 34.71, 2.96, -0.41, FALSE),
    (3, 1, 3, 'ACTIVE_SAMPLING', '2026-09-19 16:04:00', 41.503262, -73.992641, 69.40, 7.28, 5.40, 31.20, 2.91, -0.28, FALSE),
    (4, 1, 4, 'ACTIVE_SAMPLING', '2026-09-19 16:16:00', 41.506921, -73.992783, 69.12, 7.45, 5.85, 28.40, 2.85, -0.05, FALSE),
    (5, 1, 5, 'SENSOR_FAULT', '2026-09-19 16:28:00', 41.510644, -73.992981, NULL, 7.61, 6.64, 8.00, 2.77, 0.23, FALSE),
    (6, 1, 6, 'ACTIVE_SAMPLING', '2026-09-19 16:40:00', 41.514173, -73.993067, 68.94, 7.50, 5.95, 26.90, 2.72, 0.31, FALSE),
    (7, 1, 7, 'ACTIVE_SAMPLING', '2026-09-19 16:52:00', 41.517831, -73.993312, 68.70, 7.70, 7.20, 10.90, 2.66, 0.38, FALSE),
    (8, 1, 8, 'ACTIVE_SAMPLING', '2026-09-19 17:04:00', 41.521384, -73.993378, 68.55, 7.67, 7.35, 13.20, 2.61, 0.42, FALSE),
    (9, 2, 1, 'ACTIVE_SAMPLING', '2026-10-03 10:15:00', 41.496087, -73.992325, 63.90, 7.70, 7.30, 11.80, 0.92, 0.05, FALSE),
    (10, 2, 2, 'ACTIVE_SAMPLING', '2026-10-03 10:27:00', 41.499687, -73.992525, 63.81, 7.42, 5.60, 30.15, 0.88, 0.08, FALSE),
    (11, 2, 3, 'ACTIVE_SAMPLING', '2026-10-03 10:39:00', 41.503262, -73.992641, 63.67, 7.33, 4.82, 33.47, 0.84, 0.11, TRUE),
    (12, 2, 4, 'ACTIVE_SAMPLING', '2026-10-03 10:51:00', 41.506879, -73.992783, 63.72, 7.25, 5.70, 29.80, 0.81, 0.15, FALSE),
    (13, 2, 5, 'ACTIVE_SAMPLING', '2026-10-03 11:03:00', 41.510556, -73.992981, 63.55, 7.55, 6.90, 9.60, 0.79, 0.19, FALSE),
    (14, 2, 6, 'ACTIVE_SAMPLING', '2026-10-03 11:15:00', 41.514227, -73.993067, 63.60, 7.38, 5.91, 30.17, 0.76, 0.22, FALSE),
    (15, 2, 7, 'ACTIVE_SAMPLING', '2026-10-03 11:27:00', 41.517769, -73.993312, 63.41, 7.62, 7.12, 14.60, 0.73, 0.26, FALSE),
    (16, 2, 8, 'ACTIVE_SAMPLING', '2026-10-03 11:39:00', 41.521416, -73.993378, 63.35, 7.59, 7.25, 10.30, 0.70, 0.29, FALSE);

-- ---------- Water samples (reading 16 has none: bottle jammed) ----------

INSERT INTO WaterSample (sample_id, reading_id, collected_at, volume_l, analyzed_at) VALUES
    (1, 1, '2026-09-19 15:42:00', 1.00, '2026-09-21 09:30:00'),
    (2, 2, '2026-09-19 15:54:00', 1.00, '2026-09-21 09:00:00'),
    (3, 3, '2026-09-19 16:06:00', 1.00, '2026-09-21 10:30:00'),
    (4, 4, '2026-09-19 16:18:00', 1.00, '2026-09-21 10:00:00'),
    (5, 5, '2026-09-19 16:30:00', 1.00, '2026-09-21 11:30:00'),
    (6, 6, '2026-09-19 16:42:00', 1.00, '2026-09-21 11:00:00'),
    (7, 7, '2026-09-19 16:54:00', 1.00, '2026-09-21 12:30:00'),
    (8, 8, '2026-09-19 17:06:00', 1.00, '2026-09-21 12:00:00'),
    (9, 9, '2026-10-03 10:17:00', 1.00, '2026-10-05 09:30:00'),
    (10, 10, '2026-10-03 10:29:00', 1.00, '2026-10-05 09:00:00'),
    (11, 11, '2026-10-03 10:41:00', 1.00, '2026-10-05 10:30:00'),
    (12, 12, '2026-10-03 10:53:00', 1.00, '2026-10-05 10:00:00'),
    (13, 13, '2026-10-03 11:05:00', 1.00, '2026-10-05 11:30:00'),
    (14, 14, '2026-10-03 11:17:00', 1.00, '2026-10-05 11:00:00'),
    (15, 15, '2026-10-03 11:29:00', 1.00, '2026-10-05 12:30:00');

-- ---------- Detections: one row per polymer found in each sample ----------

INSERT INTO SampleDetection (sample_id, polymer_id, particle_count, absorbance, wavelength_nm) VALUES
    (1, 1, 5, 0.04534143, 1215.0),
    (1, 2, 5, 0.07512928, 1680.0),
    (1, 3, 3, 0.06460210, 1660.0),
    (1, 4, 1, 0.07101762, 1690.0),
    (1, 5, 1, 0.03755576, 1715.0),
    (2, 1, 37, 0.21110693, 1215.0),
    (2, 2, 19, 0.06556157, 1680.0),
    (2, 3, 24, 0.17872099, 1660.0),
    (2, 4, 7, 0.16220225, 1690.0),
    (2, 5, 4, 0.25552531, 1715.0),
    (3, 1, 18, 0.10478878, 1215.0),
    (3, 2, 14, 0.11270297, 1680.0),
    (3, 3, 11, 0.09692250, 1660.0),
    (3, 4, 5, 0.05514940, 1690.0),
    (3, 5, 3, 0.06621166, 1715.0),
    (4, 1, 22, 0.12783368, 1215.0),
    (4, 2, 19, 0.13487583, 1680.0),
    (4, 3, 14, 0.08191998, 1660.0),
    (4, 4, 6, 0.05516331, 1690.0),
    (4, 5, 3, 0.07707315, 1715.0),
    (5, 1, 6, 0.06190163, 1215.0),
    (5, 2, 6, 0.05702012, 1680.0),
    (5, 3, 4, 0.07621406, 1660.0),
    (5, 4, 2, 0.05958320, 1690.0),
    (5, 5, 1, 0.03148518, 1715.0),
    (6, 1, 25, 0.14756663, 1215.0),
    (6, 2, 20, 0.13319995, 1680.0),
    (6, 3, 16, 0.09224741, 1660.0),
    (6, 4, 6, 0.07658491, 1690.0),
    (6, 5, 4, 0.04215132, 1715.0),
    (7, 1, 5, 0.05685331, 1215.0),
    (7, 2, 4, 0.04016040, 1680.0),
    (7, 3, 3, 0.04222108, 1660.0),
    (7, 4, 1, 0.07289998, 1690.0),
    (7, 5, 1, 0.04418379, 1715.0),
    (8, 1, 7, 0.09752163, 1215.0),
    (8, 2, 6, 0.06593240, 1680.0),
    (8, 3, 4, 0.06637656, 1660.0),
    (8, 4, 3, 0.07562977, 1690.0),
    (8, 5, 1, 0.05834418, 1715.0),
    (9, 1, 6, 0.04957657, 1215.0),
    (9, 2, 5, 0.06945421, 1680.0),
    (9, 3, 4, 0.06768647, 1660.0),
    (9, 4, 2, 0.03705990, 1690.0),
    (9, 5, 1, 0.02873362, 1715.0),
    (10, 1, 25, 0.16373970, 1215.0),
    (10, 2, 20, 0.12568907, 1680.0),
    (10, 3, 16, 0.09369194, 1660.0),
    (10, 4, 6, 0.06663005, 1690.0),
    (10, 5, 4, 0.04690940, 1715.0),
    (11, 1, 32, 0.18791210, 1215.0),
    (11, 2, 25, 0.14502401, 1680.0),
    (11, 3, 20, 0.10512140, 1660.0),
    (11, 4, 9, 0.09690640, 1690.0),
    (11, 5, 5, 0.04447676, 1715.0),
    (12, 1, 26, 0.13803344, 1215.0),
    (12, 2, 20, 0.10139987, 1680.0),
    (12, 3, 17, 0.12501706, 1660.0),
    (12, 4, 7, 0.05369373, 1690.0),
    (12, 5, 4, 0.06228823, 1715.0),
    (13, 1, 5, 0.04464918, 1215.0),
    (13, 2, 6, 0.06802187, 1680.0),
    (13, 3, 3, 0.06626861, 1660.0),
    (13, 4, 1, 0.05074252, 1690.0),
    (13, 5, 1, 0.04675835, 1715.0),
    (14, 1, 27, 0.15224355, 1215.0),
    (14, 2, 22, 0.12985213, 1680.0),
    (14, 3, 18, 0.12177233, 1660.0),
    (14, 4, 7, 0.05274271, 1690.0),
    (14, 5, 4, 0.05972591, 1715.0),
    (15, 1, 6, 0.05581317, 1215.0),
    (15, 2, 5, 0.08327266, 1680.0),
    (15, 3, 3, 0.07895101, 1660.0),
    (15, 4, 2, 0.03132244, 1690.0),
    (15, 5, 1, 0.03116485, 1715.0);
