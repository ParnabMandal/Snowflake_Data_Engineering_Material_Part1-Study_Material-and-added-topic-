USE ROLE SYSADMIN;
CREATE OR REPLACE WAREHOUSE OPENFLOW_WH WAREHOUSE_SIZE='XSmall';
CREATE OR REPLACE DATABASE OPENFLOW;
CREATE OR REPLACE SCHEMA OPENFLOW;

USE WAREHOUSE OPENFLOW_WH;
USE DATABASE OPENFLOW;
USE SCHEMA OPENFLOW;

-- Create network rule to allow Snowflake to talk to CrunchyBridge database server
CREATE OR REPLACE NETWORK RULE POSTGRES_RULE
  TYPE = 'HOST_PORT'
  MODE = 'EGRESS'
  VALUE_LIST = ('p.2kmycnvwbfetlncclctgjc2oiy.db.postgresbridge.com:5432')
  COMMENT = 'Allow outbound traffic to the external PostgreSQL database on port 5432.';
  

-- Creates secret from Postgres password
-- You'll need to ask Dustin Brimberry for this password
CREATE OR REPLACE SECRET crunchy_bridge_postgres_password
    TYPE = GENERIC_STRING
    SECRET_STRING = 'zs0TgcYKTr7AAZmgPW0D9PWhi8IAyeaYKMjSw9t1Gj05p10E7OjVRaoVlk7TrfWZ';

CREATE OR REPLACE NETWORK RULE EGRESS_ALL_HTTPS
  TYPE = 'HOST_PORT'
  MODE = 'EGRESS'
  VALUE_LIST = ('0.0.0.0:443')
  COMMENT = 'Allow outbound traffic to internet over HTTPS';

-- Create external access integration with Postgres network rule and password
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION OPENFLOW_DEMO
  ALLOWED_NETWORK_RULES = (POSTGRES_RULE, EGRESS_ALL_HTTPS)
  ENABLED = true
  ALLOWED_AUTHENTICATION_SECRETS = ('crunchy_bridge_postgres_password');


-- Change the SCHEMA to be EXERCISES which is used in demo
CREATE OR REPLACE SCHEMA EXERCISES;
USE SCHEMA EXERCISES;

-- Python function that notebook will use to securely get the Postgres password
CREATE OR REPLACE FUNCTION get_postgres_password()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.12
HANDLER = 'get_secret'
EXTERNAL_ACCESS_INTEGRATIONS = (OPENFLOW_DEMO)
SECRETS = ('crunchy_bridge_postgres_password' = OPENFLOW.crunchy_bridge_postgres_password)
AS
$$
import _snowflake

def get_secret():
  return _snowflake.get_generic_secret_string('crunchy_bridge_postgres_password')
$$;

-- Create stage to load JSON files into
CREATE OR REPLACE STAGE STG_POSTGRES_DATA;

-- Create table for postgres data
CREATE OR REPLACE TABLE PG_CUSTOMERS (
	CUSTOMER_ID NUMBER(38,0),
	FIRST_NAME VARCHAR(100),
	LAST_NAME VARCHAR(100),
	FULL_NAME VARCHAR(201),
	EMAIL VARCHAR(255),
	REGISTRATION_DATE DATE,
	STATUS VARCHAR(20),
	COUNTRY VARCHAR(50),
	AGE NUMBER(38,0),
	LOAD_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP()
);

-- We need ACCOUNTADMIN for a few admin-y things
USE ROLE ACCOUNTADMIN;

-- Use account event table and allow SYSADMIN to write to it
GRANT APPLICATION ROLE SNOWFLAKE.EVENTS_ADMIN TO ROLE SYSADMIN;

-- Ensure events are sent to SNOWFLAKE.TELEMETRY.EVENTS table
ALTER ACCOUNT SET EVENT_TABLE = SNOWFLAKE.TELEMETRY.EVENTS;
SHOW OPENFLOW DATA PLANE INTEGRATIONS ->> SELECT "name" FROM $1;
SET OPENFLOW_DATAPLANE_NAME = (SELECT "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
EXECUTE IMMEDIATE $$
BEGIN
  EXECUTE IMMEDIATE 'ALTER OPENFLOW DATA PLANE INTEGRATION ' || $OPENFLOW_DATAPLANE_NAME || ' SET EVENT_TABLE = SNOWFLAKE.TELEMETRY.EVENTS;';
END;
$$;

-- Allow any IP address access, ideally this should only be the Openflow subnets
CREATE OR REPLACE NETWORK POLICY OPENFLOW_DEMO_POLICY
  ALLOWED_IP_LIST = ('0.0.0.0/0');

-- Create user that Openflow will use
CREATE OR REPLACE USER OPENFLOW_DEMO 
    TYPE = SERVICE
    NETWORK_POLICY = openflow_demo_policy;
GRANT ROLE SYSADMIN TO USER OPENFLOW_DEMO;

-- Uncomment to remove PAT if you need to regenerate
-- ALTER USER OPENFLOW_DEMO REMOVE PROGRAMMATIC ACCESS TOKEN OPENFLOW_ACCESS;
ALTER USER OPENFLOW_DEMO ADD PROGRAMMATIC ACCESS TOKEN OPENFLOW_ACCESS
  ROLE_RESTRICTION = SYSADMIN
  COMMENT = 'Token for Openflow user. This should be copy and pasted into the password for the SnowflakeConnectionService controller service in Openflow';

