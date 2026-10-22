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



    