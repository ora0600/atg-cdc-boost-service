-- connect as sysdba
CONNECT sys/confluent123 AS SYSDBA
-- enable goldengate replication
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
-- Change Redo log size
alter database add logfile group 4  '/opt/oracle/oradata/XE/redo04.log' size 2G;
alter database add logfile group 5  '/opt/oracle/oradata/XE/redo05.log' size 2G;
alter database add logfile group 6  '/opt/oracle/oradata/XE/redo06.log' size 2G;
alter system switch logfile;
-- disable old
alter system archive log group 1;
alter system archive log group 2;
alter system archive log group 3;
-- drop old
execute sys. dbms_lock. sleep(60);
ALTER DATABASE DROP LOGFILE GROUP 1; 
ALTER DATABASE DROP LOGFILE GROUP 2;
ALTER DATABASE DROP LOGFILE GROUP 3;
-- change SGA and PGA
alter system set sga_target=42G scope=spfile sid='*';
ALTER SYSTEM SET pga_aggregate_limit=14G SCOPE=BOTH;
-- XE
--alter system set sga_target=1G scope=spfile sid='*';
--ALTER SYSTEM SET pga_aggregate_limit=1G SCOPE=BOTH;
-- Enable archive log
shutdown immediate
startup mount
alter database archivelog;
alter database open;
ALTER SESSION SET CONTAINER=cdb$root;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER SESSION SET CONTAINER=XEPDB1;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
-- Made Logging asynchronous
ALTER SYSTEM SET commit_logging = 'BATCH' CONTAINER=ALL;
ALTER SYSTEM SET commit_wait = 'NOWAIT' CONTAINER=ALL;
exit;
