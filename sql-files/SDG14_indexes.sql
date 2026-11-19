-- =====================================================================
-- SDG 14 Hudson River Water Quality Database
-- SDG14_add_indexes.sql  |  run AFTER SDG14_create_tables.sql
--
-- MySQL auto-creates indexes for PRIMARY KEY, UNIQUE, and FOREIGN KEY
-- columns. The indexes below are the ADDITIONAL secondary indexes that
-- support the filters, ranges, and groupings in SDG14_queries.sql.
-- Each notes the query it helps.
-- =====================================================================
USE sdg14_hudson;

-- Q2 groups detections by polymer. The composite PK (sample_id, polymer_id)
-- leads with sample_id, so polymer-first lookups aren't served by it.
CREATE INDEX idx_detection_polymer
    ON SampleDetection (polymer_id);
    

-- Q3 / time-series: filtering and ordering readings by when they were taken.
CREATE INDEX idx_reading_recorded_at
    ON Reading (recorded_at);
    
    
-- Q4: filtering readings whose dissolved oxygen falls below the 5mg/L
-- aquatic-life threshold. The queries file Q4 references this as idx_reading_do.
CREATE INDEX idx_reading_do
	ON Reading (dissolved_oxygen_mgl);
    
    
-- Q5: classifying sampling points as near vs. away from a runoff source.
CREATE INDEX idx_point_runoff_distance
    ON SamplingPoint (runoff_distance_m);
    
    
-- Q8 and alert review: finding faulted or hazardous readings quickly.
CREATE INDEX idx_reading_hazard_flag
    ON Reading (hazard_flag);


-- Finding samples still awaiting lab analysis (analyzed_at IS NULL) or
-- filtering by analysis date.
CREATE INDEX idx_sample_analyzed_at
    ON WaterSample (analyzed_at);