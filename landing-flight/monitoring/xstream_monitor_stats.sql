--run as c##ggadmin on ORCLCDB
set linesize 300
--ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';
ALTER SESSION set container=CDB$ROOT;

prompt global_name
prompt ===========
select global_name from global_name;

prompt time
Prompt ====
select sysdate from dual;

prompt redo log scanning latency
Prompt =========================
COLUMN CAPTURE_NAME HEADING 'Capture|Process|Name' FORMAT A12
COLUMN LATENCY_SECONDS HEADING 'Latency|in|Seconds' FORMAT 999999
COLUMN LAST_STATUS HEADING 'Seconds Since|Last Status' FORMAT 999999
COLUMN CAPTURE_TIME HEADING 'Current|Process|Time'
COLUMN CREATE_TIME HEADING 'Message|Creation Time' FORMAT 999999
SELECT CAPTURE_NAME,
		STATE,
       ((SYSDATE - CAPTURE_MESSAGE_CREATE_TIME)*86400) LATENCY_SECONDS,
       ((SYSDATE - CAPTURE_TIME)*86400) LAST_STATUS,
       TO_CHAR(CAPTURE_TIME, 'HH24:MI:SS MM/DD/YY') CAPTURE_TIME,       
       TO_CHAR(CAPTURE_MESSAGE_CREATE_TIME, 'HH24:MI:SS MM/DD/YY') CREATE_TIME
  FROM gV$XSTREAM_CAPTURE;
  
prompt processed low position for outbound server
Prompt ==========================================
COLUMN SERVER_NAME HEADING 'Outbound|Server|Name' FORMAT A10
COLUMN SOURCE_DATABASE HEADING 'Source|Database' FORMAT A20
COLUMN PROCESSED_LOW_POSITION HEADING 'Processed|Low LCR|Position' FORMAT A30
COLUMN PROCESSED_LOW_TIME HEADING 'Processed|Low|Time' FORMAT A9
SELECT SERVER_NAME,
       SOURCE_DATABASE,
       PROCESSED_LOW_POSITION,
       TO_CHAR(PROCESSED_LOW_TIME,'HH24:MI:SS MM/DD/YY') PROCESSED_LOW_TIME
FROM ALL_XSTREAM_OUTBOUND_PROGRESS;

Prompt Connected user
Prompt =============
SELECT SERVER_NAME, 
       CONNECT_USER, 
       CAPTURE_NAME, 
       SOURCE_DATABASE,
       CAPTURE_USER,
       QUEUE_OWNER
  FROM ALL_XSTREAM_OUTBOUND;

prompt messages captured and enqueued
Prompt ===============================
COLUMN CAPTURE_NAME HEADING 'Capture|Name' FORMAT A15
COLUMN STATE HEADING 'State' FORMAT A25
COLUMN TOTAL_MESSAGES_CAPTURED HEADING 'Redo|Entries|Evaluated|In Detail' FORMAT 99999999999999
COLUMN TOTAL_MESSAGES_ENQUEUED HEADING 'Total|LCRs|Enqueued' FORMAT 99999999999999
SELECT CAPTURE_NAME,
       STATE,
       TOTAL_MESSAGES_CAPTURED,
       TOTAL_MESSAGES_ENQUEUED 
  FROM gV$XSTREAM_CAPTURE;
  
prompt xstream transactions with 0 cumulative message count
Prompt =====================================================
select 'No Rows', count(*) from gv$xstream_transaction where CUMULATIVE_MESSAGE_COUNT =0
union all
select 'With Rows', count(*) from gv$xstream_transaction where CUMULATIVE_MESSAGE_COUNT >0;

prompt apply usage
Prompt ===========
SELECT APPLY_NAME AS APP,
SGA_USED/(1024*1024) AS USED_IN_MB,
SGA_ALLOCATED/(1024*1024) AS ALLOCATE_IN_MBD,
TOTAL_MESSAGES_DEQUEUED AS DEQUEUED,
TOTAL_MESSAGES_SPILLED AS SPILLED
FROM gV$XSTREAM_APPLY_READER;

prompt capture usage
Prompt =============
SELECT CAPTURE_NAME AS CAP,
SGA_USED/(1024*1024) AS USED_IN_MB,
SGA_ALLOCATED/(1024*1024) AS ALLOCATED_IN_MB,
TOTAL_MESSAGES_CAPTURED AS CAPTURED,
TOTAL_MESSAGES_ENQUEUED AS ENQUEUED
FROM gV$XSTREAM_CAPTURE;

Prompt Fallen behind
Prompt =============
COLUMN CAPTURE_NAME HEADING 'Capture|Name' FORMAT A15
COLUMN STATE HEADING 'State' FORMAT A15
COLUMN CREATE_MESSAGE HEADING 'Last LCR|Create Time'
COLUMN ENQUEUE_MESSAGE HEADING 'Last|Enqueue Time'
SELECT CAPTURE_NAME, STATE,
       TO_CHAR(CAPTURE_MESSAGE_CREATE_TIME, 'HH24:MI:SS MM/DD/YY') CREATE_MESSAGE,
       TO_CHAR(ENQUEUE_MESSAGE_CREATE_TIME, 'HH24:MI:SS MM/DD/YY') ENQUEUE_MESSAGE
  FROM V$XSTREAM_CAPTURE;

prompt streams sgastat
Prompt ===============
select * from gv$sgastat where pool like '%streams%' and BYTES > 1000 order by BYTES desc;

prompt replication events
Prompt ==================
select * FROM ALL_REPLICATION_PROCESS_EVENTS where EVENT_TIME > (sysdate-7) order by EVENT_TIME desc;

Prompt Statistics
prompt ==========
COLUMN SERVER_NAME HEADING 'Outbound|Server|Name' FORMAT A8
COLUMN TOTAL_TRANSACTIONS_SENT HEADING 'Total|Trans|Sent' FORMAT 9999999
COLUMN TOTAL_MESSAGES_SENT HEADING 'Total|LCRs|Sent' FORMAT 9999999999
COLUMN BYTES_SENT HEADING 'Total|MB|Sent' FORMAT 99999999999999
COLUMN ELAPSED_SEND_TIME HEADING 'Time|Sending|LCRs|(in seconds)' FORMAT 99999999
COLUMN LAST_SENT_MESSAGE_NUMBER HEADING 'Last|Sent|Message|Number' FORMAT 99999999
COLUMN LAST_SENT_MESSAGE_CREATE_TIME HEADING 'Last|Sent|Message|Creation|Time' FORMAT A9
SELECT SERVER_NAME,
       TOTAL_TRANSACTIONS_SENT,
       TOTAL_MESSAGES_SENT,
       (BYTES_SENT/1024)/1024 BYTES_SENT_IN_MB,
       (ELAPSED_SEND_TIME/100) ELAPSED_SEND_TIME,
       LAST_SENT_MESSAGE_NUMBER,
       TO_CHAR(LAST_SENT_MESSAGE_CREATE_TIME,'HH24:MI:SS MM/DD/YY') 
          LAST_SENT_MESSAGE_CREATE_TIME
  FROM V$XSTREAM_OUTBOUND_SERVER;
 
Prompt Stream pool size too small
Prompt ==========================
SELECT STATE FROM V$PROPAGATION_RECEIVER;
--If the state is WAITING FOR MEMORY, then consider increasing the Streams pool size.
SELECT a.TOTAL_MEMORY_ALLOCATED/(a.CURRENT_SIZE/100) as used_size_inPercentage , a.* FROM V$STREAMS_POOL_STATISTICS a;

Prompt To determine whether the maximum SGA size for the capture process is too small:
Prompt ===============================================================================
SELECT CAPTURE_NAME AS CAP,
        SGA_USED/(1024*1024) AS USED, 
        SGA_ALLOCATED/(1024*1024) AS ALLOCATED, 
        TOTAL_MESSAGES_CAPTURED AS CAPTURED, 
        TOTAL_MESSAGES_ENQUEUED AS ENQUEUED 
  FROM V$XSTREAM_CAPTURE;
--If the USED field is equal to or almost equal to the ALLOCATED field in the output, then you might need to increase the maximum SGA size for the capture process.
SELECT SESSION_NAME AS CAP, 
        MAX_MEMORY_SIZE/(1024*1024) AS LMMAX, 
        USED_MEMORY_SIZE/(1024*1024) AS LMUSED, 
        USED_MEMORY_SIZE/MAX_MEMORY_SIZE AS PCT 
  FROM V$LOGMNR_SESSION;
--If the PCT field is equal to or almost equal to 1 in the output, then you might need to increase the maximum SGA size for the capture process.

prompt Capture latency
prompt ===============
SELECT CAPTURE_NAME,
       ((SYSDATE - CAPTURE_MESSAGE_CREATE_TIME)*86400) LATENCY_SECONDS
  FROM V$XSTREAM_CAPTURE;
--
SELECT CAPTURE_NAME,
STATE,
((SYSDATE - CAPTURE_MESSAGE_CREATE_TIME)*86400) LATENCY_SECONDS,
((SYSDATE - CAPTURE_TIME)*86400) LAST_STATUS,
TO_CHAR(CAPTURE_TIME, 'HH24:MI:SS MM/DD/YY') CAPTURE_TIME,
TO_CHAR(CAPTURE_MESSAGE_CREATE_TIME, 'HH24:MI:SS MM/DD/YY') CREATE_TIME
FROM gV$XSTREAM_CAPTURE;
-- if latency is too high, check if server is running
SELECT APPLY_NAME, 
       STATUS,
       ERROR_NUMBER,
       ERROR_MESSAGE
  FROM DBA_APPLY
  WHERE PURPOSE = 'XStream Out';

Prompt Missing Redo logs
Prompt =================
COLUMN CAPTURE_NAME HEADING 'Capture Name' FORMAT A30
COLUMN STATE HEADING 'State' FORMAT A30
SELECT CAPTURE_NAME, STATE FROM V$XSTREAM_CAPTURE;

Prompt The XStream Out Client Application Is Unresponsive
Prompt ==================================================
SELECT STATE FROM V$PROPAGATION_RECEIVER;

Prompt Pool statistcis
prompt ===============
SELECT TOTAL_MEMORY_ALLOCATED/CURRENT_SIZE FROM V$STREAMS_POOL_STATISTICS;

Prompt MAX SGA used
Prompt ============
SELECT CAPTURE_NAME AS CAP,
        SGA_USED/(1024*1024) AS USED_IN_MB, 
        SGA_ALLOCATED/(1024*1024) AS ALLOCATED_IN_MB, 
        TOTAL_MESSAGES_CAPTURED AS CAPTURED, 
        TOTAL_MESSAGES_ENQUEUED AS ENQUEUED 
  FROM V$XSTREAM_CAPTURE;

Prompt Logminer
Prompt ========
SELECT SESSION_NAME AS CAP, 
        MAX_MEMORY_SIZE/(1024*1024) AS LMMAX_IN_MB, 
        USED_MEMORY_SIZE/(1024*1024) AS LMUSED_IN_MB, 
        USED_MEMORY_SIZE/MAX_MEMORY_SIZE AS PCT 
  FROM V$LOGMNR_SESSION;

Prompt Growth of gv$xstream_transaction without reducing its size, one can use this query to monitor if it returns large number of rows:
Prompt =================================================================================================================================
select count(*) from gv$xstream_transaction,dba_xstream_outbound_progress where LAST_MESSAGE_NUMBER < PROCESSED_LOW_SCN;

Prompt The xStream propagation receiver component of database goes into 'waiting for memory' state eventually and will not move out of that, this another query can be used to confirm that:
Prompt =====================================================================================================================================================================================
select TOTAL_MSGS, HIGH_WATER_MARK, ACKNOWLEDGEMENT, STATE from gv$propagation_receiver;

Prompt Status and errors
Prompt =================
SELECT APPLY_NAME, 
       STATUS,
       ERROR_NUMBER,
       ERROR_MESSAGE
  FROM DBA_APPLY
  WHERE PURPOSE = 'XStream Out';

Prompt Alerts
Prompt ======
COLUMN REASON HEADING 'Reason for Alert' FORMAT A35
COLUMN SUGGESTED_ACTION HEADING 'Suggested Response' FORMAT A35
SELECT REASON, SUGGESTED_ACTION 
   FROM DBA_OUTSTANDING_ALERTS
   WHERE MODULE_ID LIKE '%XSTREAM%';
COLUMN REASON HEADING 'Reason for Alert' FORMAT A35
COLUMN SUGGESTED_ACTION HEADING 'Suggested Response' FORMAT A35
SELECT REASON, SUGGESTED_ACTION 
   FROM DBA_ALERT_HISTORY 
   WHERE MODULE_ID LIKE '%XSTREAM%';
   
Prompt STREAMS_POOL_SIZE Analysis
Prompt ==========================
-- If the value returned is.90 or greater, then consider increasing the Streams pool size.
SELECT TOTAL_MEMORY_ALLOCATED/CURRENT_SIZE FROM V$STREAMS_POOL_STATISTICS;
--streams_pool_advice
SELECT streams_pool_size_for_estimate, streams_pool_size_factor, estd_spill_count, to_char(sysdate,'dd-mon-yyyy HH24:MI:SS') "Current Time" FROM V$STREAMS_POOL_ADVICE;
select * from v$sgastat where pool like '%streams%' and BYTES > 1000 order by BYTES desc;

--Regarding outbound server capture & apply, use the max_sga_size capture and apply parameter to control the amount of SGA memory allocated specifically to the process. The streams pool will need to be sized to support both processes.
--If USED value is equal to or almost equal to ALLOCATED value, increase max_sga_size for the process and streams pool size accordingly.
SELECT APPLY_NAME AS APP,
SGA_USED/(1024*1024) AS USED,
SGA_ALLOCATED/(1024*1024) AS ALLOCATED,
TOTAL_MESSAGES_DEQUEUED AS DEQUEUED,
TOTAL_MESSAGES_SPILLED AS SPILLED
FROM V$XSTREAM_APPLY_READER;
SELECT CAPTURE_NAME AS CAP,
SGA_USED/(1024*1024) AS USED,
SGA_ALLOCATED/(1024*1024) AS ALLOCATED,
TOTAL_MESSAGES_CAPTURED AS CAPTURED,
TOTAL_MESSAGES_ENQUEUED AS ENQUEUED
FROM V$XSTREAM_CAPTURE;

prompt outbound server parameter
prompt =========================
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
  ORDER BY a.PARAMETER;

prompt Schema/Table APPLY
prompt =========================
set pagesize 100
set linesize 80
set echo on
set tab off
col schema_name format a12
col object_name format a12
select schema_name, object_name, rule_type, streams_type
	from dba_xstream_rules
	--where schema_name = 'ORDERMGMT'
	order by rule_type,streams_type;

Prompt COMMITSCN
COLUMN SERVER_NAME HEADING 'Outbound|Server|Name' FORMAT A10
COLUMN 'Transaction ID' HEADING 'Transaction|ID' FORMAT A11
COLUMN COMMITSCN HEADING 'Commit SCN' FORMAT 99999999999999999
COLUMN COMMIT_POSITION HEADING 'Commit Position' FORMAT A20
COLUMN LAST_SENT_POSITION HEADING 'Last Sent|Position' FORMAT A15
COLUMN MESSAGE_SEQUENCE HEADING 'Message|Number' FORMAT 999999999

SELECT SERVER_NAME,
       XIDUSN ||'.'|| 
       XIDSLT ||'.'||
       XIDSQN "Transaction ID",
       COMMITSCN,
       COMMIT_POSITION,
       LAST_SENT_POSITION,
       MESSAGE_SEQUENCE
  FROM V$XSTREAM_OUTBOUND_SERVER;