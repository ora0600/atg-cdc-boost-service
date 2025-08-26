-- I follow the setup of this database https://github.com/ora0600/confluent-new-cdc-connector/tree/main/oraclexe21c
-- supported DB Versions are 19c, 21c EE
connect sys /confluent123@XE as SYSDBA
-- To enable XStream, run the following statement
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
-- Archive LOG must enabled
SELECT LOG_MODE FROM V$DATABASE;
-- If SELECT Show ARCHIVELOG you can skip the next steps
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
SELECT LOG_MODE FROM V$DATABASE;
-- enable supplemental logging for entire DB, better per table
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
-- enable supplemental logging per table
--ALTER TABLE ORDERMGMT.ORDER_ITEMS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.ORDERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.EMPLOYEES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.PRODUCTS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.CUSTOMERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.INVENTORIES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.PRODUCT_CATEGORIES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.CONTACTS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.NOTES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.WAREHOUSES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.LOCATIONS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.COUNTRIES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--ALTER TABLE ORDERMGMT.REGIONS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
-- Configure XStream Connector User
-- Forst the tablespace for XStream Admin
CREATE TABLESPACE xstream_adm_tbs DATAFILE '/opt/oracle/oradata/XE/xstream_adm_tbs.dbf' SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
-- Create a new user for the XStream administrator.
CREATE USER cfltadmin IDENTIFIED BY Confluent12! DEFAULT TABLESPACE xstream_adm_tbs QUOTA UNLIMITED ON xstream_adm_tbs;
-- grant privileges to XStream ADMIN
GRANT CREATE SESSION TO cfltadmin;
BEGIN
  DBMS_XSTREAM_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'cfltadmin',
    privilege_type          => 'CAPTURE',
    grant_select_privileges => TRUE);
END;
/
-- Configure the Xstream Connect user
-- First the tablespace
CREATE TABLESPACE xstream_tbs DATAFILE '/opt/oracle/oradata/XE/xstream_tbs.dbf' SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
-- Create a new user for the XStream connect user.
CREATE USER cfltuser IDENTIFIED BY Confluent12! DEFAULT TABLESPACE xstream_tbs QUOTA UNLIMITED ON xstream_tbs;
-- Grant privileges
GRANT CREATE SESSION TO cfltuser;
GRANT SELECT_CATALOG_ROLE TO cfltuser;
-- better set for specific tables and not all
GRANT SELECT ANY TABLE TO cfltuser;
GRANT LOCK ANY TABLE TO cfltuser;
GRANT FLASHBACK ANY TABLE TO cfltuser;
-- for specific tables
--GRANT SELECT ON ORDERMGMT.ORDER_ITEMS TO cfltuser;
--GRANT SELECT ON ORDERMGMT.ORDERS TO cfltuser;
--GRANT SELECT ON ORDERMGMT.EMPLOYEES TO cfltuser;
--GRANT SELECT ON ORDERMGMT.PRODUCTS TO cfltuser;
--GRANT SELECT ON ORDERMGMT.CUSTOMERS TO cfltuser;
--GRANT SELECT ON ORDERMGMT.INVENTORIES TO cfltuser;
--GRANT SELECT ON ORDERMGMT.PRODUCT_CATEGORIES TO cfltuser;
--GRANT SELECT ON ORDERMGMT.CONTACTS TO cfltuser;
--GRANT SELECT ON ORDERMGMT.NOTES TO cfltuser;
--GRANT SELECT ON ORDERMGMT.WAREHOUSES TO cfltuser;
--GRANT SELECT ON ORDERMGMT.LOCATIONS TO cfltuser;
--GRANT SELECT ON ORDERMGMT.COUNTRIES TO cfltuser;
--GRANT SELECT ON ORDERMGMT.REGIONS TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.ORDER_ITEMS TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.ORDERS TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.EMPLOYEES TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.PRODUCTS TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.CUSTOMERS TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.INVENTORIES TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.PRODUCT_CATEGORIES TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.CONTACTS TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.NOTES TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.WAREHOUSES TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.LOCATIONS TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.COUNTRIES TO cfltuser;
--GRANT FLASHBACK ON ORDERMGMT.REGIONS TO cfltuser;

-- Now create the XStream Outbound Server in DB
connect cfltadmin/Confluent12!@XE
-- Run the CREATE_OUTBOUND procedure.
DECLARE
  tables  DBMS_UTILITY.UNCL_ARRAY;
  schemas DBMS_UTILITY.UNCL_ARRAY;
BEGIN
  tables(1)   := 'ORDERMGMT.ORDERS';
    tables(2)   := 'ORDERMGMT.ORDER_ITEMS';
    tables(3)   := 'ORDERMGMT.EMPLOYEES';
    tables(4)   := 'ORDERMGMT.PRODUCTS';
    tables(5)   := 'ORDERMGMT.CUSTOMERS';
    tables(6)   := 'ORDERMGMT.INVENTORIES';
    tables(7)   := 'ORDERMGMT.PRODUCT_CATEGORIES';
    tables(8)   := 'ORDERMGMT.CONTACTS';
    tables(9)   := 'ORDERMGMT.NOTES';
    tables(10)  := 'ORDERMGMT.WAREHOUSES';
    tables(11)  := 'ORDERMGMT.LOCATIONS';
    tables(12)  := 'ORDERMGMT.COUNTRIES';
    tables(13)  := 'ORDERMGMT.REGIONS';
    tables(14)  := NULL;
    schemas(1)  := NULL; 
  DBMS_XSTREAM_ADM.CREATE_OUTBOUND(
     server_name           =>  'XOUT',
     capture_name          =>  'CAPTURE_XOUT1',
     table_names           =>  tables,
     schema_names          =>  schemas);
END;
/
-- After creating the outbound server, change the connect user
BEGIN
  DBMS_XSTREAM_ADM.ALTER_OUTBOUND(
     server_name  => 'XOUT',
     connect_user => 'cfltuser');
END;
/
-- Set the Stream POOL Size
BEGIN
  DBMS_XSTREAM_ADM.SET_PARAMETER(
    streams_type => 'capture',
    streams_name => 'CAPTURE_XOUT1',
    parameter    => 'max_sga_size',
    value        => '1024');
END;
/
BEGIN
  DBMS_XSTREAM_ADM.SET_PARAMETER(
    streams_type => 'apply',
    streams_name => 'XOUT',
    parameter    => 'max_sga_size',
    value        => '1024');
END;
/
-- Configure retention time to 7 days
BEGIN
  DBMS_CAPTURE_ADM.ALTER_CAPTURE(
    capture_name              => 'CAPTURE_XOUT1',
    checkpoint_retention_time => 7);
END;
/

-- Now, on DB side everything is setup, please keep an eye on everything including tablespaces
-- You can now start the connector, floow documentation here: https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/getting-started.html#install-oracle-xstream-cdc-connector
-- Examples are here: https://github.com/ora0600/confluent-new-cdc-connector/tree/main/cdc-connector