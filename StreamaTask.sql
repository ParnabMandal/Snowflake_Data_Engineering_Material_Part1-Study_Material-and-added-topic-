-- Stream and Task demo: MERGE from staging to prod via stream with filtered source to avoid nondeterministic MERGE errors
-- Co-authored with CoCo
USE ROLE fund_role;
CREATE WAREHOUSE IF NOT EXISTS INSTRUCTOR1_fund_wh;
USE WAREHOUSE INSTRUCTOR1_fund_wh;
CREATE DATABASE IF NOT EXISTS INSTRUCTOR1_fund_db;
CREATE OR REPLACE SCHEMA INSTRUCTOR1_fund_db.streamstask;
USE SCHEMA INSTRUCTOR1_fund_db.streamstask;


-- Create the staging table (Source)
CREATE OR REPLACE TABLE members_staging (
    id INT,
    name STRING,
    status STRING
);

-- Create the final production table (Target)
CREATE OR REPLACE TABLE members_prod (
    id INT,
    name STRING,
    status STRING,
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


CREATE OR REPLACE STREAM members_stream ON TABLE members_staging;


CREATE OR REPLACE TASK process_members_changes_tsk
    WAREHOUSE = INSTRUCTOR1_fund_wh         -- Specify your virtual warehouse
    SCHEDULE = '1 MINUTE'            -- Evaluates every minute
    WHEN SYSTEM$STREAM_HAS_DATA('members_stream') -- Only runs if data exists
AS
    MERGE INTO members_prod target
    USING (
        SELECT * FROM members_stream
        WHERE METADATA$ACTION = 'INSERT'  -- Only process INSERT actions (covers both new inserts and the "new" side of updates)
        OR (METADATA$ACTION = 'DELETE' AND METADATA$ISUPDATE = FALSE)  -- Only process true deletes, not the "old" side of updates
    ) source
    ON target.id = source.id
    -- If the record exists in target and was updated/changed in staging
    WHEN MATCHED AND source.METADATA$ACTION = 'INSERT' AND source.METADATA$ISUPDATE = TRUE THEN
        UPDATE SET target.name = source.name, target.status = source.status, target.updated_at = CURRENT_TIMESTAMP()
    -- If the record is deleted from staging
    WHEN MATCHED AND source.METADATA$ACTION = 'DELETE' THEN
        DELETE
    -- If the record is brand new
    WHEN NOT MATCHED AND source.METADATA$ACTION = 'INSERT' THEN
        INSERT (id, name, status, updated_at) 
        VALUES (source.id, source.name, source.status, CURRENT_TIMESTAMP());


ALTER TASK process_members_changes_tsk RESUME;

EXECUTE TASK process_members_changes_tsk;


INSERT INTO members_staging (id, name, status) VALUES (1, 'Alice', 'Active');


SELECT * FROM members_prod;   -- Alice will appear here
SELECT * FROM members_stream; -- Will now return 0 rows (consumed)

update members_staging set name='Alice john' where id=1;
INSERT INTO members_staging (id, name, status) VALUES (2, 'Mukesh', 'Active');

update members_staging set name='Mukesh Shukla' where id=2;

select * from members_staging;

ALTER TASK process_members_changes_tsk SUSPEND;
