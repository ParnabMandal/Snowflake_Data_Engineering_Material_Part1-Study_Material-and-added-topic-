USE ROLE DE_ROLE;
USE SCHEMA instructor1_de_db.public;

-- This is the shape of the existing network rule 

CREATE OR REPLACE NETWORK RULE demo_api_network_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('api.openweathermap.org');

USE ROLE ACCOUNTADMIN;

-- Here we introduce a SECRET as well...
-- NOTE: this token comes from your openweather account 
-- NOTE: you need to replace <add your token in here> with your own token from openweather.org
CREATE OR REPLACE SECRET openweathermap_api_token
  TYPE = GENERIC_STRING
  SECRET_STRING = 'd9812caa56438f403e174e8fd86e9946';

SHOW SECRETS;


-- note that this is a READ priv, not USAGE
GRANT READ ON SECRET openweathermap_api_token TO ROLE DE_ROLE;


-- alter the integration to have access to this secret   
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION demo_api_external_access_integration
  ALLOWED_NETWORK_RULES = (demo_api_network_rule)
  ALLOWED_AUTHENTICATION_SECRETS = (openweathermap_api_token)
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION demo_api_external_access_integration TO ROLE DE_ROLE;  

SHOW EXTERNAL ACCESS INTEGRATIONS;  


-- Switch back to the end user role
USE ROLE DE_ROLE;

USE SCHEMA instructor1_de_db.public;
-- create the handler function - again, not that only Java and Python handlers are currently supported...
CREATE OR REPLACE FUNCTION get_openweather_data_api_location_python(location STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.11
HANDLER = 'get_openweather_data_api_location'
EXTERNAL_ACCESS_INTEGRATIONS = (demo_api_external_access_integration)
PACKAGES = ('snowflake-snowpark-python','requests')
SECRETS = ('cred' = openweathermap_api_token )
AS
$$
import _snowflake
import requests
import json
session = requests.Session()
def get_openweather_data_api_location(location):
    token = _snowflake.get_generic_secret_string('cred')
    url = f"https://api.openweathermap.org/data/2.5/weather?q={location}&APPID={token}"
    response = session.get(url)
    return response.json()
$$;


-- Try out calls to the API via this new function 
    -- wrap with parse_json to prettify the output 
select parse_json(GET_OPENWEATHER_DATA_API_LOCATION_PYTHON('london'));

select parse_json(GET_OPENWEATHER_DATA_API_LOCATION_PYTHON('Bangalore'));
