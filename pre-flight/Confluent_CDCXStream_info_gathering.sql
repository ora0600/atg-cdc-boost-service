-- Confluent Oracle XStream Connector BOOST-Service by ATG
-- Usage:
-- Run as DBA or Goldengate Admin on your NON-CDB or CDB.
-- sqlplus c##ggadmin@orclcdb @Confluent_CDCXStream_info_gathering.sql
-- DEFINE ONWER AND TABLES YOU WANT to use later with CDC Connector
-- see results: !more Confluent_CDCXStream_info_gathering.txt
-- 
DEFINE L_OWNER="'ORDERMGMT'" -- comma separated list
DEFINE L_TABLES="'ORDER_ITEMS','ORDERS','EMPLOYEES','PRODUCTS','CUSTOMERS','INVENTORIES','PRODUCT_CATEGORIES','CONTACTS','NOTES','WAREHOUSES','LOCATIONS','COUNTRIES,REGIONS'" -- comma separated list

set lines 299
set pages 999
spool Confluent_CDCXStream_info_gathering.txt

PROMPT ========================================
PROMPT ==== 1. DB Memory Setup Information ====
PROMPT ========================================
Prompt

PROMPT ==== displays SGA Setup Part 1====
COLUMN name HEADING 'init.ora|Param' FORMAT A20
COLUMN value HEADING 'Param|value' FORMAT A20
select name, 
       value 
  from v$parameter 
  where upper(name) in ('SGA_MAX_SIZE','SGA_MIN_SIZE','SGA_TARGET','PGA_AGGREGATE_TARGET','SHARED_POOL_SIZE') 
  order by 1;  

PROMPT ==== displays Automatic Memory Management (AMM) Setup Part 2 (MEMORY_TARGET, MEMORY_MAX_TARGET > 0 if enabled)====
select name, 
       value 
  from v$parameter 
  where upper(name) in ('MEMORY_TARGET','MEMORY_MAX_TARGET') 
  order by 1;  

PROMPT ==== Stream Pool Size====
select name, 
       value 
  from v$parameter 
  where upper(name) in ('STREAMS_POOL_SIZE') 
  order by 1;  

PROMPT ==== displays summary information about the system global area (SGA). Part 2====
COLUMN MB HEADING 'Memory|Size|in MB' FORMAT 9999999999999999
select NAME,
       VALUE/1024/1024 as MB,
       con_id
  from v$sga order by 1,3;

PROMPT ==== displays SGA Component size ====
COLUMN MB HEADING 'Current|Size|in MB' FORMAT 9999999999999999
select component, 
       current_size/1024/1024 MB 
  from v$sga_dynamic_components 
   order by 1;

PROMPT ==== displays information about the current Streams pool usage percentage ====
COLUMN MEM_ALLOC_inMB HEADING 'Stream Memory|allocated|in MB' FORMAT 9999999999999999
COLUMN size_in_MB HEADING 'current|size|in MB' FORMAT 9999999999999999
COLUMN sga_in_MB HEADING 'SGA|target|in MB' FORMAT 9999999999999999
COLUMN asked2shrink_in_MB HEADING 'POOLsize|ask2shrink|in MB' FORMAT 9999999999999999
select TOTAL_MEMORY_ALLOCATED/1024/1024 as MEM_ALLOC_inMB,
       CURRENT_SIZE/1024/1204 as size_in_MB,
       SGA_TARGET_VALUE/1024/1204 as sga_in_MB,
       SHRINK_PHASE/1024/1204 as asked2shrink_in_MB,
       CON_ID
  from V$STREAMS_POOL_STATISTICS;

PROMPT ==== Displaying SGA Usage of PDBs ====
COLUMN sga_in_MB HEADING 'SGA Usage| of PDB|in MB' FORMAT 9999999999
COLUMN pga_in_MB HEADING 'PGA Usage| of PDB|in MB' FORMAT 9999999999
COLUMN buffer_in_MB  HEADING 'Buffer Cache Usage| of PDB|in MB' FORMAT 9999999999
COLUMN shared_in_MB  HEADING 'Shared Pool Usage| of PDB|in MB' FORMAT 9999999999
COLUMN PDB_NAME FORMAT A10
SELECT r.CON_ID, 
       p.PDB_NAME, 
       r.SGA_BYTES/1024/1024 as sga_in_MB, 
       r.PGA_BYTES/1024/1024 as pga_in_MB, 
       r.BUFFER_CACHE_BYTES/1024/1024 as buffer_in_MB, 
       r.SHARED_POOL_BYTES/1024/1024 as shared_in_MB
  FROM V$RSRCPDBMETRIC r, CDB_PDBS p WHERE r.CON_ID = p.CON_ID;

PROMPT ========================================
PROMPT ==== 2. DB Setup Information        ====
PROMPT ========================================
Prompt

PROMPT ==== Cores of DB: CPUS,Cores, Sockets ====
-- Amount of CPUs
select name,  value  from v$parameter where name like 'cpu_count';
COLUMN stat_name HEADING 'Stat|Name' FORMAT A20
SELECT stat_name, TO_CHAR(value) num_cpus FROM v$osstat WHERE stat_name = 'NUM_CPUS';
-- amount of cores
SELECT stat_name, TO_CHAR(value) num_cores FROM v$osstat WHERE stat_name = 'NUM_CPU_CORES';
-- check the socket
SELECT stat_name, TO_CHAR(value) num_sockets FROM v$osstat WHERE stat_name = 'NUM_CPU_SOCKETS';


PROMPT ==== Archive Log Mode ====
SELECT LOG_MODE FROM V$DATABASE; 

Prompt ==== Supplement Logging ====
SELECT SUPPLEMENTAL_LOG_DATA_MIN, SUPPLEMENTAL_LOG_DATA_ALL FROM V$DATABASE;

PROMPT ==== Long running transactions ====
column username format a15
column program format a15
column status format a15
column name format a20
column sql_text format a50
select s.username, 
       s.program, 
       s.status as sessionstatus, 
       t.status as transactionstatus,
       t.name, 
       t.START_SCN, 
       t.START_TIME,
       to_char(sysdate,'MM/DD/YY HH24:MI:SS') as current_time,
       o.sql_text
  from v$session s, v$transaction t, v$open_cursor o 
 where s.taddr = t.addr
   and t.status='ACTIVE'
   and o.sql_id = s.prev_sql_id;

PROMPT ==== Redo log structure ====
column name heading 'Filename' format a50
SELECT
   a.group#,
   substr(b.member,1,30) name,
   a.members,
   a.bytes/1024/1024 as MB,
   a.status
FROM
   v$log     a,
   v$logfile b
WHERE
   a.group# = b.group#;

PROMPT ==== Hourly Archive generation from last seven days ====
--===========================================================================
--Hourly Archive generation from sysdate-7 to sysdate (Last 7 days) in MB
--===========================================================================
col Day for a9
set lines 300 pages 300
set num 6 
SELECT 
  TRUNC(COMPLETION_TIME), THREAD#, TO_CHAR(COMPLETION_TIME, 'Day') Day,
  COUNT(1) "Count Files",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '00', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H0",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '01', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H1",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '02', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H2",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '03', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H3",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '04', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H4",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '05', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H5",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '06', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H6",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '07', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H7",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '08', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H8",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '09', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H9",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '10', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H10",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '11', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H11",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '12', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H12",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '13', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H13",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '14', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H14",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '15', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H15",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '16', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H16",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '17', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H17",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '18', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H18",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '19', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H19",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '20', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H20",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '21', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H21",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '22', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H22",
  ROUND(SUM(DECODE(TO_CHAR(COMPLETION_TIME, 'HH24'), '23', ((BLOCKS * BLOCK_SIZE) / 1024 / 1024), 0))) "H23",
  ROUND(SUM(BLOCKS * BLOCK_SIZE) / 1024 / 1024) "Total Size (MB)"
FROM V$ARCHIVED_LOG 
WHERE COMPLETION_TIME BETWEEN sysdate-7 AND sysdate
GROUP BY TRUNC(COMPLETION_TIME), THREAD#, TO_CHAR (COMPLETION_TIME, 'Day')
ORDER BY 1;

PROMPT ====see if your redo log files are too small ====
-- You can view the redo_buffer_allocation_retries in V$SYSSTAT to see if your redo log files are too small.
select * from V$SYSSTAT where name = 'redo_buffer_allocation_retries';

PROMPT ==== time between log switches ====
-- shows you the time between log switches
select  b.recid,
        to_char(b.first_time, 'dd-mon-yy hh:mi:ss') start_time, 
        a.recid,
        to_char(a.first_time, 'dd-mon-yy hh:mi:ss') end_time,
        round(((a.first_time-b.first_time)*25)*60,2) minutes
from    v$log_history a, v$log_history b
where   a.recid = b.recid + 1
order   by a.first_time asc;

PROMPT ==== Log switches ====
-- log switches
SELECT
    substr(to_char(first_time, 'DD-MON-YYYY HH24:MI:SS'),13, 2) as Hour ,
    substr(to_char(first_time, 'DD-MON-YYYY HH24:MI:SS'),1, 12) as Day ,
    count(1) as Nb_switch_per_hour
FROM (
    SELECT DISTINCT CAST(FIRST_TIME AS VARCHAR2(20)), FIRST_TIME, FIRST_CHANGE#, NEXT_TIME, NEXT_CHANGE#,BLOCKS, BLOCK_SIZE,BLOCKS*BLOCK_SIZE AS BLOCK_TOT, ARCHIVED, END_OF_REDO, 1 AS Nb_redo
    FROM v$archived_log
    WHERE CAST(FIRST_TIME AS VARCHAR2(20)) LIKE '%1%-APR-23%'
)
GROUP BY
    substr(to_char(first_time, 'DD-MON-YYYY HH24:MI:SS'),13, 2),
    substr(to_char(first_time, 'DD-MON-YYYY HH24:MI:SS'),1, 12)
    --WHERE ROWNUM < 10
ORDER BY
    Hour ASC;


PROMPT ==== Table Growth ====

COLUMN owner FORMAT A15
COLUMN OBJECT_NAME FORMAT A25
COLUMN SUBOBJECT_NAME FORMAT A15
COLUMN OBJECT_TYPE FORMAT A15
COLUMN NAME FORMAT A15
COLUMN bytes HEADING 'Megabytes' FORMAT 9999999
SELECT o.OWNER , o.OBJECT_NAME , o.SUBOBJECT_NAME , o.OBJECT_TYPE ,
   t.NAME "Tablespace Name", s.growth/(1024*1024) "Growth in MB",
   (SELECT sum(bytes)/(1024*1024)
   FROM dba_segments
   WHERE segment_name=o.object_name) "Total Size(MB)"
FROM DBA_OBJECTS o,
   ( SELECT TS#,OBJ#,
       SUM(SPACE_USED_DELTA) growth
   FROM DBA_HIST_SEG_STAT
   GROUP BY TS#,OBJ#
   HAVING SUM(SPACE_USED_DELTA) > 0
   ORDER BY 2 DESC ) s,
   v$tablespace t
WHERE (o.owner IN (&L_OWNER) and o.OBJECT_NAME IN (&L_TABLES))
and s.OBJ# = o.OBJECT_ID
AND o.OBJECT_TYPE = 'TABLE'
AND s.TS#=t.TS#
ORDER BY 6 DESC
/



PROMPT ========================================
PROMPT ==== 3. Table Information.          ====
PROMPT ========================================
Prompt

column owner format A15
column tables format A20

PROMPT ==== LOB columns ====
ALTER SESSION SET CONTAINER=ORCLPDB1;
column mycolumns heading 'LOB|column' format a50
select OWNER||'.'||TABLE_NAME||'('||COLUMN_NAME||' '||DATA_TYPE||')' as mycolumns 
from all_tab_columns 
where OWNER IN (&L_OWNER) and table_name in (&L_TABLES)
  and data_type in ('CLOB','BLOB','NCLOB','LONG','LONG RAW','XMLTYPE','JSON');

SET ECHO OFF 
SET TERMOUT OFF 
SET FEEDBACK OFF 
SET TIMING OFF 
SET PAUSE OFF 
SET PAGESIZE 0 
SET LINESIZE 255  
SPOOL tmp.sql 
SELECT 'SELECT RPAD('''||table_name||''',30),RPAD('''||        tablespace_name||''',24), ' ||        'TO_CHAR(COUNT(*),''9,999,999,999'') FROM ' || owner||'.'||table_name || ';' FROM DBA_tables 
where OWNER IN (&L_OWNER) and table_name in (&L_TABLES)
ORDER BY table_name; 
SPOOL OFF
SET TERMOUT ON  
SET LINESIZE 80  
SPOOL schema.lst  
PROMPT Tables Overview 
PROMPT =============== 
PROMPT 
PROMPT Table                           Tablespace              Number of Rows 
PROMPT =============================== ======================= ==============
@tmp.sql
spool off
HOST cat schema.lst >> Confluent_CDCXStream_info_gathering.txt
ALTER SESSION SET CONTAINER=CDB$ROOT;
