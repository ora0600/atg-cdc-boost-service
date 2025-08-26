-- Usage:
-- sqlplus c##ggadmin@orclcdb @DB_memory_SGA_check.sql
-- If you run into this error: ORA-04031: unable to allocate 72 bytes of shared memory ("streams pool","unknown object","apply shared t","KNGLHDR_SPOS")
-- Check Memory of OS Machine: grep MemTotal /proc/meminfo
-- MemTotal:       65021392 kB = 62 GB
-- Check if max_sga_size value of outbound parameter is greater than the database SGA size
--     e.g sga_max_size big integer 42G 
--         sga_target   big integer 42G
--          In sum 42 GB:
--           Buffers      40704MB
--           Fixed Size      19MB
--           Redo Buffers   109MB
--           Variable Size 2176MB
--                Total:   43008MB SGA = 42 GB
-- streams pool  256MB
-- shared pool  1664MB 
-- Curent Stream Pool:
--    Stream Memory           current               SGA          POOLsize                                                                                                                                                 
--        allocated              size            target        ask2shrink                                                                                                                                                 
--            in MB             in MB             in MB             in MB     CON_ID                                                                                                                                      
-- ----------------- ----------------- ----------------- ----------------- ----------                                                                                                                                      
--               26               218             36578                 0          0  
--
-- Outbound Server                                                       Set by                                                                                                                                                                                                                                                                                                                                                                  
-- Name            Parameter                      Value                  User?                                                                                                                                                                                                                                                                                                                                                                   
-- --------------- ------------------------------ ---------------------- ----------                                                                                                                                                                                                                                                                                                                                                              
-- XOUT            MAX_SGA_SIZE                   INFINITE               NO                                                                                                                                                                                                                                                                                                                                                                      
--
-- Result: MAX_SGA_SIZE < SGA Size

set lines 299
set pages 999
spool DB_memory_SGA_check.txt

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

PROMPT ==== Displaying the Apply Parameter Setting MAX_SGA_SIZE for an Outbound Server ====
COLUMN APPLY_NAME HEADING 'Outbound Server|Name' FORMAT A15
COLUMN PARAMETER HEADING 'Parameter' FORMAT A30
COLUMN VALUE HEADING 'Value' FORMAT A22
COLUMN SET_BY_USER HEADING 'Set by|User?' FORMAT A10
SELECT APPLY_NAME,
       PARAMETER, 
       VALUE,
       SET_BY_USER  
  FROM ALL_APPLY_PARAMETERS a, ALL_XSTREAM_OUTBOUND o
  WHERE a.APPLY_NAME=o.SERVER_NAME
    and a.parameter in ('MAX_SGA_SIZE','EAGER_SIZE','PARALLELISM','MAX_PARALLELISM','WRITE_ALERT_LOG')
  ORDER BY a.PARAMETER;

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

PROMPT ==== If waiting for memory increase Stream Pool size ====
SELECT STATE FROM V$PROPAGATION_RECEIVER;  
PROMPT ==== If the value returned is.90 or greater, then consider increasing the Streams pool size ====
SELECT TOTAL_MEMORY_ALLOCATED/CURRENT_SIZE FROM V$STREAMS_POOL_STATISTICS;

PROMPT ==== displays detailed information on the system global area (SGA) ====
COLUMN pool HEADING 'Pool| Name' FORMAT A25
COLUMN name HEADING 'SGA|component|Name' FORMAT A26
COLUMN memsize_in_MB HEADING 'Memory|Size|in MB' FORMAT 9999999999999999
select POOL,
       NAME,
       BYTES/1024/1024 as memsize_in_MB,
       CON_ID
    from V$SGASTAT
   order by con_id, pool;

spool off