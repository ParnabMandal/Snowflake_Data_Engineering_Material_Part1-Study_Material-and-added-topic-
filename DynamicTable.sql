
-- 5.0.0   Dynamic Tables OPTIONAL
--         By the end of this lab, you will be able to:
--         - Create Dynamic Tables.
--         - Observe Information about Dynamic Tables in Snowsight.
--         In this lab, we will emulate a utility power provider.

-- 5.1.0   Set your context and Create test tables
--         You will create three TABLES.
--         Customers that contains some customers as illustration for the lab.
--         Orders that contains some sample orders for the lab.
--         Customers_Orders which is a Dynamic Table which joins and aggregates
--         the customers and orders tables.

-- 5.1.1   Open the lab SQL File in Workspaces and set the context.

USE ROLE DE_role;
CREATE WAREHOUSE IF NOT EXISTS TURTLE_DE_WH;
USE WAREHOUSE TURTLE_DE_WH;
CREATE DATABASE IF NOT EXISTS TURTLE_fund_db;
CREATE OR REPLACE SCHEMA TURTLE_fund_db.dynamic_tables;
USE SCHEMA TURTLE_fund_db.dynamic_tables;


-- 5.1.2   Create the Customers and Orders Tables.

CREATE TABLE TURTLE_fund_db.dynamic_tables.customers (customer_id INT, name STRING, state STRING);
CREATE TABLE TURTLE_fund_db.dynamic_tables.orders (order_id INT, customer_id INT, amt INT);


-- 5.1.3   Next create a dynamic table of customers and order totals.

CREATE OR REPLACE DYNAMIC TABLE TURTLE_fund_db.dynamic_tables.customers_orders
   TARGET_LAG = '1 minutes'
   WAREHOUSE = TURTLE_DE_wh
   AS
      SELECT c.customer_id, c.name, SUM(amt) AS total_purchases
      FROM TURTLE_fund_db.dynamic_tables.customers c
      LEFT OUTER JOIN TURTLE_fund_db.dynamic_tables.orders o ON c.customer_id = o.customer_id
      GROUP BY ALL;

--         Dynamic tables currently require you to specify a virtual warehouse
--         for their processing.
--         Dynamic tables also require Cloud Services compute to identify
--         changes in underlying base objects and whether the virtual warehouse
--         needs to be invoked. If no changes are identified, virtual warehouse
--         credits aren’t consumed since there’s no new data to refresh. Note
--         that there may be instances where changes in base objects are
--         filtered out in the dynamic table query. In such scenarios, virtual
--         warehouse credits are consumed because the dynamic table undergoes a
--         refresh to determine whether the changes are applicable.
--         If the associated virtual warehouse is suspended and no changes in
--         base objects are identified, the suspended virtual warehouse doesn’t
--         get invoked and no credits are consumed. Conversely, if changes are
--         identified, the virtual warehouse is automatically resumed to process
--         the updates.

-- 5.1.4   View the status of the dynamic table.
--         Unlike tasks, upon the creation of a dynamic table’s DDL, the dynamic
--         table is in an ACTIVE state; i.e., dynamic tables do not require an
--         additional step of resuming them.
--         Run the following to verify that the dynamic table’s scheduling_state
--         is set to ACTIVE.

SHOW DYNAMIC TABLES IN SCHEMA TURTLE_fund_db.dynamic_tables;


-- 5.2.0   View Dynamic Tables Using Snowsight
--         You can view the dynamic table using Snowsight. Below is a screenshot
--         for your reference.

-- 5.2.1   Open a new Snowsight browser tab.
--         In Snowsight’s left navigation, hover over the Catalog Icon and right
--         mouse click on Database Explorer then click Open Link in New Tab.
--         Do the following:
--         Switch to the new browser tab and locate the
--         TURTLE_fund_db.dynamic_tables schema and expand Dynamic Tables.
--         Select the dynamic table CUSTOMERS_ORDERS and peruse the contents of
--         the various tabs in the right pane.
--         - Table Details: Displays the definition of the dynamic table and the
--         privileges granted for working with the dynamic table
--         - Columns: Displays information about the columns in the dynamic
--         table.
--         - Data Preview: Preview of up to 100 rows of the data in the dynamic
--         table once it has data.
--         - Graph: Displays the directed acyclic graph (DAG) that includes this
--         dynamic table.
--         - Refresh History: Displays the history of refreshes.
--         We refer to this dynamic-tables section of Snowsight as the Dynamic
--         Table Tab in the instructions throughout this lab.

-- 5.2.2   From your SQL workspaces file, select from the Dynamic Table.
--         Obviously no data will be available, as neither of the source tables
--         has had any data inserted yet. Also, you need to select a virtual
--         warehouse to process Data Preview, Graph, Refresh History, and Data
--         Quality.

SELECT * FROM TURTLE_fund_db.dynamic_tables.customers_orders;


-- 5.3.0   Populate the test data

-- 5.3.1   Populate the customers and orders table with some data.

INSERT INTO TURTLE_fund_db.dynamic_tables.customers(customer_id, name, state)
VALUES (1, 'Aaron', 'NY'),
       (2, 'Bob', 'MA');

INSERT INTO TURTLE_fund_db.dynamic_tables.orders(order_id, customer_id, amt)
VALUES (1, 1, 100),
       (2, 1, 200),
       (3, 2, 15);


-- 5.3.2   Verify the contents of your three tables.
--         You may need to wait up to one minute for the dynamic table,
--         customers_orders, to be populated, due to its defined 1-minute
--         TARGET_LAG.

SELECT * FROM TURTLE_fund_db.dynamic_tables.customers ORDER BY customer_id ASC;
SELECT * FROM TURTLE_fund_db.dynamic_tables.orders ORDER BY order_id ASC;
SELECT * FROM TURTLE_fund_db.dynamic_tables.customers_orders ORDER BY customer_id ASC;

--         You should now see the customers IDs and a sum of their purchases in
--         the dynamic table, customers_orders.

-- 5.3.3   Insert more customers.

INSERT INTO dynamic_tables.customers(customer_id, name, state)
VALUES (3, 'Chris', 'IL'),
       (4, 'Diana', 'MO');


-- 5.3.4   Wait for about a minute.
--         Refreshed data will not be available in the dynamic table for up to a
--         minute, given the TARGET_LAG.

SELECT * FROM TURTLE_fund_db.dynamic_tables.customers_orders ORDER BY customer_id ASC;


-- 5.3.5   Insert more orders.

INSERT INTO TURTLE_fund_db.dynamic_tables.orders(order_id, customer_id, amt)
VALUES (4, 3, 1000),
       (5, 3, 2000),
       (6, 4, 999);

--         You can actually FORCE a REFRESH of the dynamic table, thus bypassing
--         its defined TARGET_LAG.

-- 5.3.6   Run the following command to manually refresh the dynamic table.

ALTER DYNAMIC TABLE TURTLE_fund_db.dynamic_tables.customers_orders REFRESH;


-- 5.3.7   Verify that the dynamic table has been refreshed.

SELECT * FROM TURTLE_fund_db.dynamic_tables.customers_orders ORDER BY customer_id ASC;

--         Dynamic tables’ results reflect the underlying data upon which they
--         are based. If you delete from the CUSTOMERS table, then the dynamic
--         table will be updated accordingly upon its next REFRESH.

-- 5.3.8   Delete all rows from the the customers table.

TRUNCATE TABLE TURTLE_fund_db.dynamic_tables.customers;

ALTER DYNAMIC TABLE TURTLE_fund_db.dynamic_tables.customers_orders REFRESH;

SELECT * FROM TURTLE_fund_db.dynamic_tables.customers_orders;


-- 5.3.9   Suspend (and verify) the refreshing of the dynamic table to avoid
--         ongoing Cloud Services compute.
--         Run the following to SUSPEND the refreshing of the dynamic table, and
--         verify that its scheduling_state is set to SUSPENDED.

ALTER DYNAMIC TABLE TURTLE_fund_db.dynamic_tables.customers_orders SUSPEND;

SHOW DYNAMIC TABLES IN SCHEMA TURTLE_fund_db.dynamic_tables;


-- 5.3.10  Return to the Dynamic Table Tab.
--         As you did earlier in this lab, using the Snowsight interface, return
--         to the Dynamic Table Tab for your dynamic table, customers_orders,
--         and review the contents of the tabs in the screen’s right pane.

-- 5.3.11  Clean up your objects.
--         From your lab’s SQL workspace file, run the following.

DROP SCHEMA TURTLE_fund_db.dynamic_tables;


-- 5.3.12  Suspend and Resize your warehouse.

ALTER WAREHOUSE TURTLE_DE_wh SUSPEND;
ALTER WAREHOUSE TURTLE_DE_wh SET
  WAREHOUSE_SIZE = XSMALL;


-- 5.4.0   Key Takeaways
--         Dynamic tables simplify data engineering in Snowflake by providing a
--         reliable, cost-effective, and automated way to transform data.
--         Instead of managing transformation steps with tasks and scheduling,
--         you define the end state using dynamic tables and let Snowflake
--         handle the pipeline management.
--         Dynamic table refreshes do NOT incur virtual warehouse credits if
--         there are NO CHANGES to the underlying tables upon which they are
--         based, but Cloud Services credits may still apply.
