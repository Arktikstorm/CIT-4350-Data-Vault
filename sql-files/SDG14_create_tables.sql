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

DROP TABLE IF EXISTS sdg14_hudson;
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

CREATE TABLE OperationalStatus (
    status_code   VARCHAR(30)  PRIMARY KEY,
    description   VARCHAR(150) NOT NULL
);

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


    