-- =====================================================================
-- SDG 14 Hudson River Water Quality Database
-- 01_create_tables.sql  |  MySQL 8.0.16+ (CHECK constraints are enforced)
--
-- Eight tables:
--   Lookup / reference : Drone, OperationalStatus, SamplingPoint, PolymerType
--   Core               : Run, Reading, WaterSample
--   Junction (M:N)     : SampleDetection  (WaterSample <-> PolymerType)
--
-- Run order: 01_create_tables.sql -> 02_insert_mock_data.sql -> 03_queries.sql
-- =====================================================================

DROP DATABASE IF EXISTS sdg14_hudson;
CREATE DATABASE sdg14_hudson;
USE sdg14_hudson;


-- ---------------------------------------------------------------------
-- Lookup / reference tables (parents, created first)
-- ---------------------------------------------------------------------

-- One row per water drone.
CREATE TABLE Drone (
	drone_id 			INT AUTO_INCREMENT PRIMARY KEY,
    drone_name			VARCHAR(50)	NOT NULL,
    model				VARCHAR(50),
    commissioned_date	DATE		NOT NULL
    );

-- Allowed status codes. A lookup table stops typos from creating
-- false categories (e.g. 'ACTIVE_SAMPLNG').

CREATE TABLE OperationalStatus (
	status_code			VARCHAR(30)	PRIMARY KEY,
    description			VARCHAR(150) NOT NULL
);

-- Fixed stops along the route, one every quarter mile.
-- Runoff columns let us compare readings near vs. away from runoff.

CREATE TABLE SamplingPoint (
    point_id               INT AUTO_INCREMENT PRIMARY KEY,
    point_label            VARCHAR(20)  NOT NULL UNIQUE,
    river_mile             DECIMAL(5,2) NOT NULL,
    latitude               DECIMAL(9,6) NOT NULL,
    longitude              DECIMAL(9,6) NOT NULL,
    nearest_runoff_source  VARCHAR(80),
    runoff_distance_m      INT,
    CHECK (latitude  BETWEEN -90  AND 90),
    CHECK (longitude BETWEEN -180 AND 180)
);

-- Plastic types the lab spectrometer can identify (PE, PP, PET, ...).

CREATE TABLE PolymerType (
    polymer_id      INT AUTO_INCREMENT PRIMARY KEY,
    polymer_name    VARCHAR(60) NOT NULL UNIQUE,
    abbreviation    VARCHAR(10) NOT NULL UNIQUE,
    common_sources  VARCHAR(120)
);

CREATE TABLE Run (
    run_id           INT AUTO_INCREMENT PRIMARY KEY,
    drone_id         INT         NOT NULL,
    water_body_name  VARCHAR(60) NOT NULL,
    start_time       DATETIME    NOT NULL,
    end_time         DATETIME,
    FOREIGN KEY (drone_id) REFERENCES Drone(drone_id),
    CHECK (end_time IS NULL OR end_time >= start_time)
);

CREATE TABLE Reading (
    reading_id            INT AUTO_INCREMENT PRIMARY KEY,
    run_id                INT          NOT NULL,
    point_id              INT          NOT NULL,
    status_code           VARCHAR(30)  NOT NULL,
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
    FOREIGN KEY (run_id)      REFERENCES Run(run_id),
    FOREIGN KEY (point_id)    REFERENCES SamplingPoint(point_id),
    FOREIGN KEY (status_code) REFERENCES OperationalStatus(status_code),
    UNIQUE (run_id, point_id),
    CHECK (water_temp_f         BETWEEN 32 AND 100),
    CHECK (ph                   BETWEEN 0 AND 14),
    CHECK (dissolved_oxygen_mgl >= 0),
    CHECK (turbidity_ntu        >= 0),
    CHECK (salinity_ppt         >= 0)
);

CREATE TABLE WaterSample (
    sample_id     INT AUTO_INCREMENT PRIMARY KEY,
    reading_id    INT          NOT NULL UNIQUE,
    collected_at  DATETIME     NOT NULL,
    volume_l      DECIMAL(4,2) NOT NULL DEFAULT 1.00,
    analyzed_at   DATETIME,
    FOREIGN KEY (reading_id) REFERENCES Reading(reading_id),
    CHECK (volume_l > 0)
);

CREATE TABLE SampleDetection (
    sample_id       INT NOT NULL,
    polymer_id      INT NOT NULL,
    particle_count  INT NOT NULL,
    absorbance      DECIMAL(10,8),
    wavelength_nm   DECIMAL(6,1),
    PRIMARY KEY (sample_id, polymer_id),
    FOREIGN KEY (sample_id)  REFERENCES WaterSample(sample_id),
    FOREIGN KEY (polymer_id) REFERENCES PolymerType(polymer_id),
    CHECK (particle_count >= 0)
);


    