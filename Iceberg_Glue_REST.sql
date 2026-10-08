-- ============================================================
-- Apache Iceberg Tables Demo (from scratch)
-- ============================================================

-- 1. CREATE EXTERNAL VOLUME (requires ACCOUNTADMIN)
--    This connects Snowflake to your S3 bucket for storing Iceberg data files.
--    Replace the placeholder values with your actual AWS details.
USE ROLE ACCOUNTADMIN;



CREATE OR REPLACE CATALOG INTEGRATION glue_rest_catalog_int
  CATALOG_SOURCE = ICEBERG_REST
  TABLE_FORMAT = ICEBERG
  REST_CONFIG = (
    CATALOG_URI = 'https://glue.eu-north-1.amazonaws.com/iceberg'
    CATALOG_API_TYPE = AWS_GLUE
    CATALOG_NAME = '484577546576' -- Your AWS Account ID (Glue Catalog ID)
  )
  REST_AUTHENTICATION = (
    TYPE = SIGV4
    SIGV4_IAM_ROLE = 'arn:aws:iam::484577546576:role/mshuklaGlueCatalogRole'
    SIGV4_SIGNING_REGION = 'eu-north-1'
  )
  ENABLED = TRUE;


 DESC INTEGRATION glue_rest_catalog_int;
-- API_AWS_EXTERNAL_ID: QPB26950_SFCRole=5_X0eS3E7wtH99eOf6E3SYY2s1SNo=
 -- API_AWS_IAM_USER_ARN: arn:aws:iam::800464326928:user/0pp62000-s

 
 CREATE OR REPLACE EXTERNAL VOLUME ext_volume_glue_rest
  STORAGE_LOCATIONS = (
    (
      NAME = 'glue-iceberg-data_rset'
      STORAGE_PROVIDER = 'S3'
      STORAGE_BASE_URL = 's3://mshukleicebergdemo/glue_rest/'
      STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::484577546576:role/mshuklaicebergdemorole'
      STORAGE_AWS_EXTERNAL_ID = '8888888abcdefgh112'
    )
  )
  ALLOW_WRITES = TRUE;

DESC EXTERNAL VOLUME ext_volume_glue_rest;
-- API_AWS_EXTERNAL_ID : 8888888abcdefgh112
--API_AWS_IAM_USER_ARN  arn:aws:iam::800464326928:user/0pp62000-s

-- IMPORTANT: After creating the external volume, you must:
-- 1. Run DESC EXTERNAL VOLUME ext_volume and note the STORAGE_AWS_IAM_USER_ARN
-- 2. Update your AWS IAM role trust policy to allow that ARN to assume the role
-- external id: abcdABCD77777666
-- STORAGE_AWS_IAM_USER_ARN: arn:aws:iam::800464326928:user/0pp62000-s
--external id: 8888888abcdefgh112


 
USE ROLE ACCOUNTADMIN;
 
GRANT USAGE ON EXTERNAL VOLUME ext_volume_glue_rest TO ROLE ARCH_role;

GRANT USAGE ON INTEGRATION glue_rest_catalog_int TO ROLE ARCH_role;

-- 2. SETUP
USE ROLE ARCH_role;
USE WAREHOUSE INSTRUCTOR1_ARCH_wh;
USE DATABASE INSTRUCTOR1_ARCH_db;

CREATE OR REPLACE SCHEMA iceberg_demo;
USE SCHEMA iceberg_demo;

-- Set the base location prefix so Iceberg files are organized by schema
ALTER SCHEMA iceberg_demo SET BASE_LOCATION_PREFIX = 'INSTRUCTOR1/iceberg_demo_glue_rest';


-- 2. CREATE AN ICEBERG TABLE
--    CATALOG='SNOWFLAKE' means Snowflake manages the Iceberg metadata.
--    EXTERNAL_VOLUME points to the pre-configured S3 storage.




-- let's create Glue catalog table using REST
-- first create a table in the GLUE by running below query in the Athena Editior

-- CREATE TABLE mshukla_glue_database.mshukla_glue_table_rest1 (
--    product_id   INT,
--    product_name STRING,
--    category     STRING,
--    price        DECIMAL(10,2)
-- )
-- LOCATION 's3://mshukleicebergdemo/glue_rest/mshukla_glue_table_rest/'

-- then create table here in the snowflake
CREATE OR REPLACE ICEBERG TABLE mshukla_glue_table_rest
  EXTERNAL_VOLUME = 'ext_volume_glue_rest'
  CATALOG = 'glue_rest_catalog_int'
  CATALOG_NAMESPACE = 'mshukla_glue_database'
  CATALOG_TABLE_NAME = 'mshukla_glue_table_rest1'
  AUTO_REFRESH = TRUE;

INSERT INTO mshukla_glue_table_rest VALUES
     (1, 'Laptop',      'Electronics', 999.99)
    ,(2, 'Headphones',  'Electronics', 149.99)
    ,(3, 'Desk Chair',  'Furniture',   299.99)
    ,(4, 'Monitor',     'Electronics', 449.99)
    ,(5, 'Standing Desk','Furniture',  599.99)
;

select * from mshukla_glue_table_rest;
-- 6. TIME TRAVEL
--    Delete some rows, then recover them using Iceberg's time travel support.
DELETE FROM mshukla_glue_table_rest WHERE category = 'Furniture';
SET delete_qid = LAST_QUERY_ID();

-- Current state (only Electronics remain)
SELECT * FROM mshukla_glue_table_rest;

-- Historical state before the delete (all rows)
SELECT * FROM mshukla_glue_table_rest BEFORE (STATEMENT => $delete_qid);

-- Restore deleted rows
INSERT INTO mshukla_glue_table_rest
    SELECT * FROM mshukla_glue_table_rest BEFORE (STATEMENT => $delete_qid)
    WHERE category = 'Furniture';

-- Confirm all 8 rows are back
SELECT * FROM mshukla_glue_table_rest ORDER BY product_id;


-- 7. JOIN ICEBERG TABLE WITH A STANDARD TABLE
CREATE OR REPLACE TABLE category_discounts (
     category        VARCHAR
    ,discount_pct    DECIMAL(5,2)
);

INSERT INTO category_discounts VALUES
     ('Electronics', 10.00)
    ,('Furniture',   15.00)
;

-- Join works seamlessly between Iceberg and standard tables
SELECT
     p.product_id
    ,p.product_name
    ,p.price
    ,d.discount_pct
    ,ROUND(p.price * (1 - d.discount_pct/100), 2) AS sale_price
FROM mshukla_glue_table_rest p
JOIN category_discounts d ON p.category = d.category
ORDER BY p.product_id;


-- 8. CLEANUP
ALTER WAREHOUSE INSTRUCTOR1_ARCH_wh SUSPEND;
