
-- 2.0.0   Data Lake Integration (Condensed Lab)
--         By the end of this lab, you will be able to:
--         - Configure a named stage for data lake storage
--         - Generate and stage dummy data as partitioned CSV files
--         - Create file formats for CSV and Parquet
--         - Create and query non-partitioned external tables
--         - Create and query partitioned external tables
--         - Compare partition pruning in query profiles
--         - Export data to Parquet and load into a VARIANT column
--         - Query semi-structured VARIANT data with path notation
--         - Create a view over a VARIANT table for friendly querying


-- =========================================================================
-- SECTION 1: Setup - Context, Database, Schema, Stage
-- =========================================================================

-- 2.1.1   Set session context.

USE ROLE ACCOUNTADMIN;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

CREATE WAREHOUSE IF NOT EXISTS INSTRUCTOR1_lake_wh WITH
    WAREHOUSE_SIZE = 'XSMALL'
    INITIALLY_SUSPENDED = TRUE
    AUTO_SUSPEND = 60;

CREATE DATABASE IF NOT EXISTS INSTRUCTOR1_lake_db;
CREATE SCHEMA IF NOT EXISTS INSTRUCTOR1_lake_db.data_lake;
USE SCHEMA INSTRUCTOR1_lake_db.data_lake;
USE WAREHOUSE INSTRUCTOR1_lake_wh;

-- 2.1.2   Create a storage integration for AWS S3.
--         A storage integration is a Snowflake object that stores the IAM
--         role ARN and allowed bucket locations. It avoids passing credentials
--         directly and can be reused across multiple stages.

CREATE STORAGE INTEGRATION IF NOT EXISTS mshukla_extstage
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::484577546576:role/mshuklaicebergdemorole'
    ENABLED = TRUE
    STORAGE_ALLOWED_LOCATIONS = ('s3://mshukleicebergdemo/');

-- 2.1.3   Verify the integration and note the STORAGE_AWS_IAM_USER_ARN
--         and STORAGE_AWS_EXTERNAL_ID. These are needed to configure the
--         trust relationship in the IAM role on AWS.

DESC INTEGRATION mshukla_extstage;

-- external id : QPB26950_SFCRole=5_c8AGc8PrpXwVwKRnEmnLrpzTedY=
-- user_arn: arn:aws:iam::800464326928:user/0pp62000-s
-- 2.1.4   Create an external stage pointing to the S3 bucket.

CREATE OR REPLACE STAGE data_lake_stage
    STORAGE_INTEGRATION = mshukla_extstage
    URL = 's3://mshukleicebergdemo/externaltable_data/'
    COMMENT = 'External stage on S3 for data lake integration lab';

-- 2.1.5   Create file formats for CSV and Parquet.

CREATE OR REPLACE FILE FORMAT csv_format
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('NULL', '')
    COMPRESSION = AUTO;

CREATE OR REPLACE FILE FORMAT parquet_format
    TYPE = PARQUET
    COMPRESSION = SNAPPY;


-- =========================================================================
-- SECTION 2: Generate and Stage Dummy Data
-- =========================================================================

-- 2.2.0   Clean up any prior lab files on the external stage.

REMOVE @data_lake_stage/csv/;
REMOVE @data_lake_stage/parquet/;

-- 2.2.1   Create a temporary table with dummy sales data.
--         We generate 1200 rows across 3 years x 4 quarters x 4 regions.

CREATE OR REPLACE TEMPORARY TABLE sales_source AS
SELECT
    UNIFORM(2022, 2024, RANDOM())::VARCHAR                          AS year,
    UNIFORM(1, 4, RANDOM())::VARCHAR                                AS quarter,
    ARRAY_CONSTRUCT('North','South','East','West')[UNIFORM(0,3,RANDOM())]::VARCHAR AS region,
    'PRD-' || LPAD(UNIFORM(1,50, RANDOM())::VARCHAR, 3, '0')       AS product_id,
    ROUND(UNIFORM(100, 50000, RANDOM())::NUMBER, 2)                 AS revenue,
    ROUND(UNIFORM(1, 500, RANDOM())::NUMBER, 2)                     AS units_sold,
    ROUND(UNIFORM(10, 5000, RANDOM())::NUMBER, 2)                   AS cost,
    DATEADD(DAY, UNIFORM(0, 89, RANDOM()),
        TO_DATE(year || '-' || LPAD((quarter::INT - 1) * 3 + 1, 2, '0') || '-01'))
                                                                    AS sale_date
FROM TABLE(GENERATOR(ROWCOUNT => 1200));

-- 2.2.2   Export data to the stage as partitioned CSV files.
--         Each COPY INTO writes files into a year=YYYY/quarter=Q/ subfolder
--         so we can demonstrate partition pruning later.

COPY INTO @data_lake_stage/csv/year=2022/quarter=1/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2022' AND quarter = '1')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

COPY INTO @data_lake_stage/csv/year=2022/quarter=2/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2022' AND quarter = '2')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

COPY INTO @data_lake_stage/csv/year=2022/quarter=3/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2022' AND quarter = '3')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

COPY INTO @data_lake_stage/csv/year=2022/quarter=4/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2022' AND quarter = '4')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

COPY INTO @data_lake_stage/csv/year=2023/quarter=1/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2023' AND quarter = '1')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

COPY INTO @data_lake_stage/csv/year=2023/quarter=2/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2023' AND quarter = '2')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

COPY INTO @data_lake_stage/csv/year=2023/quarter=3/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2023' AND quarter = '3')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

COPY INTO @data_lake_stage/csv/year=2023/quarter=4/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2023' AND quarter = '4')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

COPY INTO @data_lake_stage/csv/year=2024/quarter=1/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2024' AND quarter = '1')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

COPY INTO @data_lake_stage/csv/year=2024/quarter=2/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2024' AND quarter = '2')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

COPY INTO @data_lake_stage/csv/year=2024/quarter=3/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2024' AND quarter = '3')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

COPY INTO @data_lake_stage/csv/year=2024/quarter=4/
    FROM (SELECT region, product_id, revenue, units_sold, cost, sale_date
          FROM sales_source WHERE year = '2024' AND quarter = '4')
    FILE_FORMAT = (TYPE = CSV)
    HEADER = TRUE
    OVERWRITE = TRUE;

-- 2.2.3   Verify the staged files.
--         You should see 12 CSV files, one per year/quarter combination.

LIST @data_lake_stage/csv/;


-- =========================================================================
-- SECTION 3: Non-Partitioned External Table
-- =========================================================================

-- 2.3.1   Create a non-partitioned external table over the CSV files.
--         REFRESH_ON_CREATE = TRUE tells Snowflake to scan the stage and
--         register all files in its metadata immediately.
--         AUTO_REFRESH would additionally trigger metadata refreshes when
--         new files land (requires cloud event notification setup).

CREATE OR REPLACE EXTERNAL TABLE sales_ext
    (
        region      VARCHAR AS (VALUE:c1::VARCHAR),
        product_id  VARCHAR AS (VALUE:c2::VARCHAR),
        revenue     NUMBER(12,2) AS (VALUE:c3::NUMBER(12,2)),
        units_sold  NUMBER(10,2) AS (VALUE:c4::NUMBER(10,2)),
        cost        NUMBER(12,2) AS (VALUE:c5::NUMBER(12,2)),
        sale_date   DATE    AS (VALUE:c6::DATE)
    )
    LOCATION = @data_lake_stage/csv/
    REFRESH_ON_CREATE = TRUE
    FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);

-- 2.3.2   Inspect the external table metadata.

SHOW EXTERNAL TABLES LIKE 'sales_ext';

--         Key columns: stage, location, file_format_name, is_external.

-- 2.3.3   Query the non-partitioned external table.

SELECT * FROM sales_ext LIMIT 10;

--         Notice the VALUE column containing the raw row alongside virtual columns.

-- 2.3.4   Run a filtered aggregate query.

SELECT SUM(revenue) AS total_revenue, COUNT(*) AS num_sales
FROM sales_ext
WHERE sale_date BETWEEN '2023-01-01' AND '2023-03-31';

--         Check the query profile: ALL partitions (files) were scanned
--         because there is no partition pruning on a non-partitioned table.


-- =========================================================================
-- SECTION 4: Partitioned External Table & Pruning
-- =========================================================================

-- 2.4.1   Create a partitioned external table.
--         year and quarter are derived from METADATA$FILENAME (the folder
--         path), enabling Snowflake to prune files that don't match the
--         WHERE clause.

CREATE OR REPLACE EXTERNAL TABLE sales_ext_partitioned
    (
        year        VARCHAR AS SPLIT_PART(SPLIT_PART(METADATA$FILENAME, '/', 3), '=', 2),
        quarter     VARCHAR AS SPLIT_PART(SPLIT_PART(METADATA$FILENAME, '/', 4), '=', 2),
        region      VARCHAR AS (VALUE:c1::VARCHAR),
        product_id  VARCHAR AS (VALUE:c2::VARCHAR),
        revenue     NUMBER(12,2) AS (VALUE:c3::NUMBER(12,2)),
        units_sold  NUMBER(10,2) AS (VALUE:c4::NUMBER(10,2)),
        cost        NUMBER(12,2) AS (VALUE:c5::NUMBER(12,2)),
        sale_date   DATE    AS (VALUE:c6::DATE)
    )
    PARTITION BY (year, quarter)
    LOCATION = @data_lake_stage/csv/
    REFRESH_ON_CREATE = TRUE
    FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);

--         Note: Partition columns MUST be derived from METADATA$FILENAME,
--         not from file content. Snowflake uses the filename-based partition
--         values to decide which files to read before opening them.
--         Do NOT confuse external table partitions with Snowflake micro-partitions.

-- 2.4.2   Run the same filtered query on the partitioned table.

SELECT year, quarter,
       SUM(revenue) AS total_revenue,
       COUNT(*)     AS num_sales
FROM sales_ext_partitioned
WHERE year = '2023' AND quarter = '1'
GROUP BY year, quarter;

--         Check the query profile: only 1 partition (file) was scanned
--         instead of all 12. This is the benefit of partition pruning.

-- 2.4.3   Refresh external table metadata.
--         If new files were added to the stage after the table was created,
--         use ALTER ... REFRESH to update the metadata.

ALTER EXTERNAL TABLE sales_ext_partitioned REFRESH;


-- =========================================================================
-- SECTION 5: Parquet Export & VARIANT Loading
-- =========================================================================

-- 2.5.1   Export the partitioned data to Parquet on the stage.

COPY INTO @data_lake_stage/parquet/sales
    FROM (SELECT * FROM sales_ext_partitioned)
    FILE_FORMAT = (TYPE = PARQUET)
    OVERWRITE = TRUE;

-- 2.5.2   Verify the Parquet files.

LIST @data_lake_stage/parquet/;

-- 2.5.3   Create a table with a single VARIANT column to hold raw data.

CREATE OR REPLACE TABLE sales_raw_history (
    data VARIANT
);

-- 2.5.4   Load the Parquet files into the VARIANT table.
--         Each Parquet row becomes a single VARIANT object (key-value pairs).

COPY INTO sales_raw_history
    FROM @data_lake_stage/parquet/sales
    FILE_FORMAT = (TYPE = PARQUET);

--         Review the COPY output: Status, Rows_Parsed, Rows_Loaded,
--         Errors_Seen. These columns are critical for debugging load issues.


-- =========================================================================
-- SECTION 6: Querying Semi-Structured VARIANT Data
-- =========================================================================

-- 2.6.1   Query the raw VARIANT data.

SELECT * FROM sales_raw_history LIMIT 10;

--         Each row is a JSON-like object. Click a cell to see key-value pairs.

-- 2.6.2   Extract columns using semi-structured path notation.

SELECT
    data:"YEAR"::VARCHAR         AS year,
    data:"QUARTER"::VARCHAR      AS quarter,
    data:"REGION"::VARCHAR       AS region,
    data:"PRODUCT_ID"::VARCHAR   AS product_id,
    data:"REVENUE"::NUMBER(12,2) AS revenue,
    data:"UNITS_SOLD"::NUMBER    AS units_sold,
    data:"COST"::NUMBER(12,2)    AS cost,
    data:"SALE_DATE"::DATE       AS sale_date
FROM sales_raw_history
LIMIT 20;

--         The data:"KEY"::TYPE syntax navigates into the VARIANT object
--         and casts the value to a relational type.

-- 2.6.3   Create a view for friendly SQL access over VARIANT data.

CREATE OR REPLACE VIEW sales_history_view AS
SELECT
    data:"YEAR"::VARCHAR         AS year,
    data:"QUARTER"::VARCHAR      AS quarter,
    data:"REGION"::VARCHAR       AS region,
    data:"PRODUCT_ID"::VARCHAR   AS product_id,
    data:"REVENUE"::NUMBER(12,2) AS revenue,
    data:"UNITS_SOLD"::NUMBER    AS units_sold,
    data:"COST"::NUMBER(12,2)    AS cost,
    data:"SALE_DATE"::DATE       AS sale_date
FROM sales_raw_history;

-- 2.6.4   Query through the view - same result, cleaner SQL.

SELECT year, quarter,
       SUM(revenue)    AS total_revenue,
       SUM(units_sold) AS total_units
FROM sales_history_view
WHERE year = '2023' AND quarter = '1'
GROUP BY year, quarter
ORDER BY year, quarter;

--         This should match the result from the partitioned external table
--         query in Section 4 - same data, now stored inside Snowflake.


-- =========================================================================
-- SECTION 7: Cleanup
-- =========================================================================

-- 2.7.1   Drop all objects created in this lab.

DROP TABLE IF EXISTS sales_raw_history;
DROP VIEW IF EXISTS sales_history_view;
DROP TABLE IF EXISTS sales_ext;
DROP TABLE IF EXISTS sales_ext_partitioned;
DROP FILE FORMAT IF EXISTS csv_format;
DROP FILE FORMAT IF EXISTS parquet_format;

-- 2.7.2   Remove data files from the external S3 stage.

REMOVE @data_lake_stage/csv/;
REMOVE @data_lake_stage/parquet/;

-- 2.7.3   Drop the stage and remaining objects.

DROP STAGE IF EXISTS data_lake_stage;
DROP SCHEMA IF EXISTS INSTRUCTOR1_lake_db.data_lake;
DROP DATABASE IF EXISTS INSTRUCTOR1_lake_db;
DROP WAREHOUSE IF EXISTS INSTRUCTOR1_lake_wh;


-- =========================================================================
-- SECTION 8: Key Takeaways
-- =========================================================================
--
-- 1. STAGES: Named stages (internal or external) provide a reusable pointer
--    to file storage. External stages point to S3/Azure/GCS buckets.
--
-- 2. EXTERNAL TABLES: Let you query files on a stage as if they were tables
--    without loading data into Snowflake. The VALUE column holds raw data;
--    virtual columns extract typed fields.
--
-- 3. PARTITION PRUNING: Partition columns derived from METADATA$FILENAME
--    let Snowflake skip irrelevant files entirely. This is critical for
--    performance on large data lakes. Do NOT confuse with micro-partitions.
--
-- 4. REFRESH: Use REFRESH_ON_CREATE=TRUE or ALTER TABLE ... REFRESH to
--    update file metadata. AUTO_REFRESH requires cloud event notifications.
--
-- 5. PARQUET + VARIANT: Loading Parquet into a VARIANT column preserves
--    the full schema. Use data:"KEY"::TYPE path notation to extract fields.
--
-- 6. VIEWS OVER VARIANT: Create views to abstract the path notation and
--    provide a clean relational interface for downstream consumers.
--
-- 7. TRADE-OFF: External tables avoid data duplication but scan all files
--    unless partitioned. Loading into Snowflake (VARIANT or relational)
--    gives full micro-partition pruning and query optimization.
