-- ============================================================
-- Apache Iceberg Tables Demo (from scratch)
-- ============================================================

-- 1. CREATE EXTERNAL VOLUME (requires ACCOUNTADMIN)
--    This connects Snowflake to your S3 bucket for storing Iceberg data files.
--    Replace the placeholder values with your actual AWS details.
USE ROLE ACCOUNTADMIN;


-- External volume for Glue-managed data (different S3 prefix from ext_volume2)
CREATE OR REPLACE EXTERNAL VOLUME ext_volume_glue
  STORAGE_LOCATIONS = (
    (
      NAME = 'glue-iceberg-data'
      STORAGE_PROVIDER = 'S3'
      STORAGE_BASE_URL = 's3://mshukleicebergdemo/glue_data/'
      STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::484577546576:role/mshuklaicebergdemorole'
      STORAGE_AWS_EXTERNAL_ID = '8888888abcdefgh112'
    )
  )
  ALLOW_WRITES = TRUE;
  
-- Verify the external volume
DESC EXTERNAL VOLUME ext_volume_glue;

-- IMPORTANT: After creating the external volume, you must:
-- 1. Run DESC EXTERNAL VOLUME ext_volume and note the STORAGE_AWS_IAM_USER_ARN
-- 2. Update your AWS IAM role trust policy to allow that ARN to assume the role
-- external id: abcdABCD77777666
-- STORAGE_AWS_IAM_USER_ARN: arn:aws:iam::800464326928:user/0pp62000-s
--external id: 8888888abcdefgh112

CREATE OR REPLACE CATALOG INTEGRATION glue_catalog_int
  CATALOG_SOURCE = GLUE
  TABLE_FORMAT = ICEBERG
  GLUE_AWS_ROLE_ARN = 'arn:aws:iam::484577546576:role/mshuklaGlueCatalogRole'
  GLUE_CATALOG_ID = '484577546576'
  GLUE_REGION = 'eu-north-1'
  ENABLED = TRUE;

  DESC INTEGRATION glue_catalog_int;
  -- external id: QPB26950_SFCRole=5_IGtlknxR0msjPCRj/zNu8rzrLjA=
  -- user-arn: arn:aws:iam::800464326928:user/0pp62000-s







 
USE ROLE ACCOUNTADMIN;

GRANT USAGE ON EXTERNAL VOLUME ext_volume_glue TO ROLE ARCH_role; 


GRANT USAGE ON INTEGRATION glue_catalog_int TO ROLE ARCH_role;


-- 2. SETUP
USE ROLE ARCH_role;
USE WAREHOUSE INSTRUCTOR1_ARCH_wh;
USE DATABASE INSTRUCTOR1_ARCH_db;

CREATE OR REPLACE SCHEMA iceberg_demo;
USE SCHEMA iceberg_demo;



-- Set the base location prefix so Iceberg files are organized by schema
ALTER SCHEMA iceberg_demo SET BASE_LOCATION_PREFIX = 'INSTRUCTOR1/iceberg_demo_glue';


-- 2. CREATE AN ICEBERG TABLE 'mshukla_glue_table' using ATHENA editior 


-- CREATE TABLE mshukla_glue_database.mshukla_glue_table (
--    product_id   INT,
--    product_name STRING,
--    category     STRING,
--    price        DECIMAL(10,2)
-- )
-- LOCATION 's3://mshukleicebergdemo/glue_data/mshukla_glue_table' TBLPROPERTIES ('table_type' = 'ICEBERG');




-- then create table here in the snowflake
CREATE OR REPLACE ICEBERG TABLE mshukla_glue_table
  EXTERNAL_VOLUME = 'ext_volume_glue'
  CATALOG = 'glue_catalog_int'
  CATALOG_NAMESPACE = 'mshukla_glue_database'
  CATALOG_TABLE_NAME = 'mshukla_glue_table'
  AUTO_REFRESH = TRUE;
  

-- 3. INSERT DATA
-- this query should fail since GLUE table without REST is read only
INSERT INTO mshukla_glue_table VALUES
     (1, 'Laptop',      'Electronics', 999.99)
    ,(2, 'Headphones',  'Electronics', 149.99)
    ,(3, 'Desk Chair',  'Furniture',   299.99)
    ,(4, 'Monitor',     'Electronics', 449.99)
    ,(5, 'Standing Desk','Furniture',  599.99)
;

-- Above query will fail, since it is read only table. go and insert the same data using Athena editor and then perform below read query
select * from mshukla_glue_table;





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
FROM mshukla_glue_table p
JOIN category_discounts d ON p.category = d.category
ORDER BY p.product_id;


-- 8. CLEANUP

ALTER WAREHOUSE INSTRUCTOR1_ARCH_wh SUSPEND;
