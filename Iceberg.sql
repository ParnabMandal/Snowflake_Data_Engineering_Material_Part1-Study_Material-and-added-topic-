-- ============================================================
-- Apache Iceberg Tables Demo (from scratch)
-- ============================================================

-- 1. CREATE EXTERNAL VOLUME (requires ACCOUNTADMIN)
--    This connects Snowflake to your S3 bucket for storing Iceberg data files.
--    Replace the placeholder values with your actual AWS details.
USE ROLE ACCOUNTADMIN;

-- arn:aws:iam::484577546576:role/mshuklaicebergdemorole

CREATE OR REPLACE EXTERNAL VOLUME ext_volume1
  STORAGE_LOCATIONS = (
    (
      NAME = 'my-s3-iceberg'
      STORAGE_PROVIDER = 'S3'
      STORAGE_BASE_URL = 's3://mshukleicebergdemo/demo/'
      STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::484577546576:role/mshuklaicebergdemorole'
      STORAGE_AWS_EXTERNAL_ID = '8888888abcdefgh112'
    )
  )
  ALLOW_WRITES = TRUE;

-- Verify the external volume
DESC EXTERNAL VOLUME ext_volume1;

-- IMPORTANT: After creating the external volume, you must:
-- 1. Run DESC EXTERNAL VOLUME ext_volume and note the STORAGE_AWS_IAM_USER_ARN
-- 2. Update your AWS IAM role trust policy to allow that ARN to assume the role
-- external id: 8888888abcdefgh112
-- STORAGE_AWS_IAM_USER_ARN: arn:aws:iam::863547508724:user/4aga2000-s
-- arn:aws:iam::217722171700:user/od5u1000-s


USE ROLE ACCOUNTADMIN;
GRANT USAGE ON EXTERNAL VOLUME ext_volume1 TO ROLE DE_role;

-- 2. SETUP
USE ROLE DE_role;
USE WAREHOUSE INSTRUCTOR1_DE_wh;
USE DATABASE INSTRUCTOR1_DE_db;

CREATE OR REPLACE SCHEMA iceberg_demo;
USE SCHEMA iceberg_demo;

-- Set the base location prefix so Iceberg files are organized by schema
ALTER SCHEMA iceberg_demo SET BASE_LOCATION_PREFIX = 'INSTRUCTOR1/iceberg_demo';


-- 2. CREATE AN ICEBERG TABLE
--    CATALOG='SNOWFLAKE' means Snowflake manages the Iceberg metadata.
--    EXTERNAL_VOLUME points to the pre-configured S3 storage.
CREATE OR REPLACE ICEBERG TABLE products (
     product_id   INT
    ,product_name VARCHAR
    ,category     VARCHAR
    ,price        DECIMAL(10,2)
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'ext_volume1';


-- 3. INSERT DATA
INSERT INTO products VALUES
     (1, 'Laptop',      'Electronics', 999.99)
    ,(2, 'Headphones',  'Electronics', 149.99)
    ,(3, 'Desk Chair',  'Furniture',   299.99)
    ,(4, 'Monitor',     'Electronics', 449.99)
    ,(5, 'Standing Desk','Furniture',  599.99)
;

-- Verify the data
SELECT * FROM products;




-- 5. INSERT MORE DATA (creates a new Parquet file)
INSERT INTO products VALUES
     (6, 'Keyboard',    'Electronics', 79.99)
    ,(7, 'Webcam',      'Electronics', 129.99)
    ,(8, 'Bookshelf',   'Furniture',   199.99)
;


select * from products;




-- 6. TIME TRAVEL
--    Delete some rows, then recover them using Iceberg's time travel support.
DELETE FROM products WHERE category = 'Furniture';
SET delete_qid = LAST_QUERY_ID();

-- Current state (only Electronics remain)
SELECT * FROM products;

-- Historical state before the delete (all rows)
SELECT * FROM products BEFORE (STATEMENT => $delete_qid);

-- Restore deleted rows
INSERT INTO products
    SELECT * FROM products BEFORE (STATEMENT => $delete_qid)
    WHERE category = 'Furniture';

-- Confirm all 8 rows are back
SELECT * FROM products ORDER BY product_id;


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
FROM products p
JOIN category_discounts d ON p.category = d.category
ORDER BY p.product_id;


-- 8. CLEANUP
ALTER WAREHOUSE INSTRUCTOR1_DE_wh SUSPEND;
