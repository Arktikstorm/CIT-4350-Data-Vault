-- =====================================================================
-- SDG 14 Hudson River Water Quality Database  |  MySQL 8.0+
-- Schema + indexes. Nine tables: 4 lookup/reference, 4 core, 1 junction.
--
-- Run order:
--   SOURCE sql-files/SDG14_create_tables.sql;      -- this file
--   SOURCE sql-files/SDG14_insert_mock_data.sql;
--   SOURCE sql-files/SDG14_queries.sql;
--
-- Re-runnable: this script drops and recreates the database each time.
-- Table names are lower_snake_case.
-- =====================================================================

DROP DATABASE IF EXISTS sdg14_hudson;
CREATE DATABASE sdg14_hudson;
USE sdg14_hudson;

-- ---------------------------------------------------------------------
-- Lookup / reference tables
-- ---------------------------------------------------------------------

CREATE TABLE drone (
    drone_id           INT AUTO_INCREMENT PRIMARY KEY,
    drone_name         VARCHAR(50)  NOT NULL,
    model              VARCHAR(50),
    commissioned_date  DATE         NOT NULL
);

CREATE TABLE operational_status (
    status_id     INT AUTO_INCREMENT PRIMARY KEY,
    status_code   VARCHAR(30)  NOT NULL UNIQUE,
    description   VARCHAR(150) NOT NULL
);

CREATE TABLE runoff_source (
    runoff_id    INT AUTO_INCREMENT PRIMARY KEY,
    source_name  VARCHAR(80) NOT NULL UNIQUE,
    source_type  VARCHAR(40)
);

CREATE TABLE polymer_type (
    polymer_id      INT AUTO_INCREMENT PRIMARY KEY,
    polymer_name    VARCHAR(60) NOT NULL UNIQUE,
    abbreviation    VARCHAR(10) NOT NULL UNIQUE,
    common_sources  VARCHAR(120)
);

-- ---------------------------------------------------------------------
-- Core tables
-- ---------------------------------------------------------------------

CREATE TABLE sampling_point (
    point_id           INT AUTO_INCREMENT PRIMARY KEY,
    point_label        VARCHAR(20)  NOT NULL UNIQUE,
    river_mile         DECIMAL(5,2) NOT NULL,
    latitude           DECIMAL(9,6) NOT NULL,
    longitude          DECIMAL(9,6) NOT NULL,
    runoff_id          INT,
    runoff_distance_m  INT,
    FOREIGN KEY (runoff_id) REFERENCES runoff_source(runoff_id),
    CHECK (latitude  BETWEEN -90  AND 90),
    CHECK (longitude BETWEEN -180 AND 180),
    CHECK (runoff_distance_m IS NULL OR runoff_distance_m >= 0)
);

CREATE TABLE run (
    run_id           INT AUTO_INCREMENT PRIMARY KEY,
    drone_id         INT         NOT NULL,
    water_body_name  VARCHAR(60) NOT NULL,
    start_time       DATETIME    NOT NULL,
    end_time         DATETIME,
    FOREIGN KEY (drone_id) REFERENCES drone(drone_id),
    CHECK (end_time IS NULL OR end_time >= start_time)
);

CREATE TABLE reading (
    reading_id            INT AUTO_INCREMENT PRIMARY KEY,
    run_id                INT          NOT NULL,
    point_id              INT          NOT NULL,
    status_id             INT          NOT NULL,
    recorded_at           DATETIME     NOT NULL,
    latitude              DECIMAL(9,6) NOT NULL,
    longitude             DECIMAL(9,6) NOT NULL,
    water_temp_f          DECIMAL(5,2),
    ph                    DECIMAL(4,2),
    dissolved_oxygen_mgl  DECIMAL(5,2),
    turbidity_ntu         DECIMAL(6,2),
    salinity_ppt          DECIMAL(5,2),
    flow_rate_ms          DECIMAL(5,2),
    hazard_flag           BOOLEAN      NOT NULL DEFAULT FALSE,
    FOREIGN KEY (run_id)    REFERENCES run(run_id),
    FOREIGN KEY (point_id)  REFERENCES sampling_point(point_id),
    FOREIGN KEY (status_id) REFERENCES operational_status(status_id),
    UNIQUE (run_id, point_id),
    CHECK (latitude             BETWEEN -90 AND 90),
    CHECK (longitude            BETWEEN -180 AND 180),
    CHECK (water_temp_f         BETWEEN 32 AND 100),
    CHECK (ph                   BETWEEN 0 AND 14),
    CHECK (dissolved_oxygen_mgl >= 0),
    CHECK (turbidity_ntu        >= 0),
    CHECK (salinity_ppt         >= 0)
);

CREATE TABLE water_sample (
    sample_id     INT AUTO_INCREMENT PRIMARY KEY,
    reading_id    INT          NOT NULL UNIQUE,
    collected_at  DATETIME     NOT NULL,
    volume_l      DECIMAL(4,2) NOT NULL DEFAULT 1.00,
    analyzed_at   DATETIME,
    FOREIGN KEY (reading_id) REFERENCES reading(reading_id),
    CHECK (volume_l > 0)
);

-- ---------------------------------------------------------------------
-- Junction table
-- ---------------------------------------------------------------------

CREATE TABLE sample_detection (
    sample_id       INT NOT NULL,
    polymer_id      INT NOT NULL,
    particle_count  INT NOT NULL,
    absorbance      DECIMAL(10,8),
    wavelength_nm   DECIMAL(6,1),
    PRIMARY KEY (sample_id, polymer_id),
    FOREIGN KEY (sample_id)  REFERENCES water_sample(sample_id),
    FOREIGN KEY (polymer_id) REFERENCES polymer_type(polymer_id),
    CHECK (particle_count >= 0)
);

-- =====================================================================
-- Secondary indexes
--
-- MySQL auto-creates indexes for PRIMARY KEY, UNIQUE, and FOREIGN KEY
-- columns. The indexes below are the ADDITIONAL secondary indexes that
-- support the filters, ranges, and groupings in SDG14_queries.sql.
-- Each notes the query it helps.
-- =====================================================================

-- Q2 groups detections by polymer. The composite PK (sample_id, polymer_id)
-- leads with sample_id, so polymer-first lookups aren't served by it.
CREATE INDEX idx_detection_polymer
    ON sample_detection (polymer_id);

-- Q3 / time-series: filtering and ordering readings by when they were taken.
CREATE INDEX idx_reading_recorded_at
    ON reading (recorded_at);

-- Q4: filtering readings whose dissolved oxygen falls below the 5 mg/L
-- aquatic-life threshold.
CREATE INDEX idx_reading_do
    ON reading (dissolved_oxygen_mgl);

-- Q5: classifying sampling points as near vs. away from a runoff source.
CREATE INDEX idx_point_runoff_distance
    ON sampling_point (runoff_distance_m);

-- Q8 and alert review: finding faulted or hazardous readings quickly.
CREATE INDEX idx_reading_hazard_flag
    ON reading (hazard_flag);

-- Finding samples still awaiting lab analysis (analyzed_at IS NULL) or
-- filtering by analysis date.
CREATE INDEX idx_sample_analyzed_at
    ON water_sample (analyzed_at);
