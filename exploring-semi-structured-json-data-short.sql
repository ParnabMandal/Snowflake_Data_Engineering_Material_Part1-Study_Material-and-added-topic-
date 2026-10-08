-- 11: Exploring Semi-Structured JSON Data (Condensed)
-- Covers: VARIANT, dot notation, LATERAL FLATTEN, nested JSON queries

USE ROLE DE_role;
USE WAREHOUSE INSTRUCTOR1_DE_WH;
USE DATABASE INSTRUCTOR1_DE_db;
USE SCHEMA public;

----------------------------------------------------------------------
-- 1. Create table with VARIANT column & insert JSON
----------------------------------------------------------------------
CREATE OR REPLACE TABLE author_ingest (raw VARIANT);

INSERT INTO author_ingest
SELECT PARSE_JSON('{
    "firstName": "Gene",
    "lastName": "Simmons",
    "age": 74,
    "email": ["gene@kiss.com", "gene.simmons@kiss.com"],
    "children": [
        { "firstName": "Nick", "gender": "Male", "age": 33 },
        { "firstName": "Sophie", "gender": "Female", "age": 30 }
    ]
}');

----------------------------------------------------------------------
-- 2. Dot notation & casting
----------------------------------------------------------------------
SELECT raw:firstName::VARCHAR AS first_name FROM author_ingest;

SELECT
    raw:firstName::VARCHAR  AS first_name,
    raw:lastName::VARCHAR   AS last_name,
    raw:age::INTEGER        AS age
FROM author_ingest;

-- Array element by index
SELECT raw:email[0]::VARCHAR AS primary_email FROM author_ingest;

-- Nested object in array
SELECT
    raw:children[0].firstName::VARCHAR AS child_name,
    raw:children[0].age::INTEGER       AS child_age
FROM author_ingest;

----------------------------------------------------------------------
-- 3. LATERAL FLATTEN to explode arrays
----------------------------------------------------------------------
SELECT f.value::VARCHAR AS email
FROM author_ingest, LATERAL FLATTEN(input => raw:email) f;

SELECT
    f.value:firstName::VARCHAR AS child_name,
    f.value:gender::VARCHAR    AS gender,
    f.value:age::INTEGER       AS age
FROM author_ingest, LATERAL FLATTEN(input => raw:children) f;

----------------------------------------------------------------------
-- 4. FLATTEN output fields: seq, key, path, index, value, this
----------------------------------------------------------------------
SELECT f.seq, f.key, f.path, f.index, f.value, f.this
FROM author_ingest, LATERAL FLATTEN(input => raw:children) f;

----------------------------------------------------------------------
-- 5. Nested JSON with arrays, aggregations & hyphenated keys
----------------------------------------------------------------------
CREATE OR REPLACE TABLE sensor_data (s VARIANT);

INSERT INTO sensor_data
SELECT PARSE_JSON('{
  "station": {
    "id": "STN-42", "name": "Roof Sensor", "region": "US-West",
    "coord": { "lat": 37.77, "lon": -122.42 }
  },
  "readings": [
    { "ts": "2024-01-15T08:00", "temp": 12.3, "wind": { "speed-rate": 5.1, "direction-angle": 180 }, "air-quality": 42 },
    { "ts": "2024-01-15T12:00", "temp": 18.7, "wind": { "speed-rate": 8.4, "direction-angle": 210 }, "air-quality": 38 },
    { "ts": "2024-01-15T18:00", "temp": 15.1, "wind": { "speed-rate": 12.0, "direction-angle": 195 }, "air-quality": 45 }
  ]
}');

-- Dot notation: station info
SELECT
    s:station.id::VARCHAR          AS station_id,
    s:station.name::VARCHAR        AS station_name,
    s:station.coord.lat::FLOAT    AS lat,
    s:station.coord.lon::FLOAT    AS lon
FROM sensor_data;

-- Dot notation: specific reading by index (hyphenated keys need quotes)
SELECT
    s:readings[1].temp::NUMBER(5,1)                    AS temp,
    s:readings[1].wind."speed-rate"::NUMBER(5,1)       AS wind_speed,
    s:readings[1]."air-quality"::INT                   AS air_quality
FROM sensor_data;

-- LATERAL FLATTEN: aggregate across all readings
SELECT
    AVG(f.value:temp)::NUMBER(5,1)                AS avg_temp,
    MAX(f.value:wind."speed-rate")::NUMBER(5,1)   AS max_wind,
    MIN(f.value:"air-quality")::INT               AS best_air_quality
FROM sensor_data, LATERAL FLATTEN(input => s:readings) f;

-- LATERAL FLATTEN: expand all readings into rows
SELECT
    f.index                                          AS reading_num,
    f.value:ts::TIMESTAMP                            AS ts,
    f.value:temp::NUMBER(5,1)                        AS temp,
    f.value:wind."speed-rate"::NUMBER(5,1)           AS wind_speed,
    f.value:wind."direction-angle"::INT              AS wind_dir,
    f.value:"air-quality"::INT                       AS air_quality
FROM sensor_data, LATERAL FLATTEN(input => s:readings) f;

----------------------------------------------------------------------
-- KEY TAKEAWAYS
-- - JSON stored in VARIANT columns
-- - Cast VARIANT to SQL types for performance
-- - Dot notation for direct access; LATERAL FLATTEN to explode arrays
-- - Array indexes start at 0; hyphenated keys need double quotes
-- - FLATTEN output fields: seq, key, path, index, value, this
----------------------------------------------------------------------
