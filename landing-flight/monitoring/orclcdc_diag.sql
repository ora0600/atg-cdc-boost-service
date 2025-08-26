--
-- Copyright [2024 - 2025] Confluent Inc.
--

-- Confluent Oracle XStream CDC Connector Diagnostics Script
--
-- This script is provided solely for diagnostic purposes. It is read-only and collects 
-- diagnostic information related to the Oracle Database and XStream configuration to assist in 
-- diagnosing issues with the Confluent Oracle XStream CDC source connector.
-- This script does not collect or process any message content.
-- 
-- Compatibility: Oracle Database version 19c and later.
--
ALTER SESSION SET nls_date_format='YYYY-MM-DD HH24:MI:SS';

SET FEEDBACK OFF
SET LINESIZE 240
SET LONG 4000
SET PAGESIZE 50000
SET TERMOUT OFF

COLUMN op_file_name NEW_VALUE v_file_name NOPRINT;
SELECT 'orclcdc_diag_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MI') || '.html' op_file_name FROM DUAL;

SPOOL &v_file_name

SET MARKUP HTML ON SPOOL ON PREFORMAT OFF ENTMAP OFF HEAD "" BODY "" TABLE "border='1' width='90%' align='center'"

PROMPT <html>
PROMPT <head> <title>Confluent Oracle XStream CDC Connector Diagnostics Script</title> </head>
PROMPT <body> <style type="text/css"> -
body { -
  font-family: consolas, monospace; -
  font-size: 9pt; -
  background-color: #F5F4F4; -
} -
table, td, th { -
  border: 1px solid #808090; -
} -
table { -
  border-collapse: collapse; -
  margin-top: 1em; -
  margin-bottom: 1em; -
} -
th { -
  background: #062756; -
  color: #FFFFFF; -
  font-family: consolas, monospace; -
  font-size: 9pt; -
} -
td { -
  font-family: consolas, monospace; -
  font-size: 9pt; -
} -
h1 { -
  color: #201371; -
  font-size: 15pt; -
  margin-top: -10pt; -
  margin-bottom: 0pt; -
} -
h2 { -
  color: #332494; -
  font-size: 12pt; -
  margin-top: 0pt; -
  margin-bottom: 0pt; -
} -
h3 { -
  color: #4933D7; -
  font-size: 10pt; -
  margin-top: 0pt; -
  margin-bottom: 0pt; -
} -
ul { -
  line-height: 0.75em; -
  margin-top: 0pt; -
  margin-bottom: 0pt; -
} -
 </style>

PROMPT <h1>Confluent Oracle XStream CDC Connector Diagnostics Script</h1>

PROMPT <ul>
PROMPT   <li><a href="#Overview"> Overview </a></li>
PROMPT   <li><a href="#Capture Process"> Capture Process </a></li>
PROMPT   <li><a href="#LogMiner"> LogMiner </a></li>
PROMPT   <li><a href="#Outbound Server"> Outbound Server </a></li>
PROMPT   <li><a href="#Apply Components"> Apply Components </a></li>
PROMPT   <li><a href="#Rules"> Rules </a></li>
PROMPT   <li><a href="#Queue"> Queue </a></li>
PROMPT   <li><a href="#Streams Pool"> Streams Pool </a></li>
PROMPT   <li><a href="#Redo Log"> Redo Log </a></li>
PROMPT   <li><a href="#Alerts"> Alerts </a></li>
PROMPT   <li><a href="#Miscellaneous"> Miscellaneous </a></li>
PROMPT </ul>

--------------
-- Overview --
--------------
PROMPT <hr>
PROMPT <h2><a name="Overview">Overview</a></h2>

-- Overview: Database
PROMPT <h3>Overview: Database</h3>

COL inst_id HEADING "Instance ID"
COL name HEADING "DB Name"
COL db_unique_name HEADING "Unique DB Name"
COL log_mode HEADING "Log Mode"
COL open_mode HEADING "Open Mode"
COL database_role HEADING "DB Role"
COL current_scn HEADING "Current SCN"
COL supplemental_log_data_min FORMAT A21 HEADING "Supplemental Log|(MIN)"
COL supplemental_log_data_pk FORMAT A20 HEADING "Supplemental Log|(PK)"
COL supplemental_log_data_all FORMAT A21 HEADING "Supplemental Log|(ALL)"
COL min_required_capture_change# HEADING "Minimum Required|Checkpoint SCN"
COL cdb HEADING "CDB"
COL platform_name HEADING "Platform Name"

SELECT
  inst_id,
  name,
  db_unique_name,
  log_mode,
  open_mode,
  database_role,
  current_scn,
  supplemental_log_data_min,
  supplemental_log_data_pk,
  supplemental_log_data_all,
  min_required_capture_change#,
  cdb,
  platform_name
FROM
  gv$database
ORDER BY
  inst_id;

-- Overview: Global database name
PROMPT <h3>Overview: Global database name</h3>

COL global_name HEADING "Global DB Name"

SELECT
  global_name
FROM
  global_name;

-- Overview: Initialization parameters
PROMPT <h3>Overview: Initialization parameters</h3>

COL inst_id HEADING "Instance ID"
COL name HEADING 'Parameter Name'
COL value HEADING 'Parameter Value'

SELECT
  inst_id,
  name,
  value
FROM
  gv$parameter
WHERE
  name IN
  ('sga_target', 'sga_max_size',
   'memory_target', 'memory_max_target',
   'pga_aggregate_target',
   'shared_pool_size', 'streams_pool_size',
   'processes', 'sessions')
ORDER BY
  inst_id;

---------------------
-- Capture Process --
---------------------
PROMPT <hr>
PROMPT <h2><a name="Capture Process">Capture Process</a></h2>

-- Capture process: General
PROMPT <h3>Capture Process: General</h3>

COL capture_name HEADING 'Capture Name'
COL capture_user HEADING 'Capture User'
COL capture_type FORMAT A12 HEADING 'Capture Type'
COL queue_name HEADING 'Queue'
COL rule_set_name HEADING 'Positive|Ruleset'
COL negative_rule_set_name HEADING 'Negative|Ruleset'
COL checkpoint_retention_time HEADING 'Checkpoint|Retention Time'
COL logminer_id HEADING 'Logminer ID'
COL source_database HEADING 'Source Database'

SELECT
  capture_name,
  capture_user,
  capture_type,
  queue_owner || '.' || queue_name queue_name,
  CASE
    WHEN rule_set_name IS NOT NULL THEN rule_set_owner || '.' || rule_set_name
    ELSE NULL
  END rule_set_name,
  CASE
    WHEN negative_rule_set_name IS NOT NULL THEN negative_rule_set_owner || '.' || negative_rule_set_name
    ELSE NULL
  END negative_rule_set_name,
  checkpoint_retention_time,
  logminer_id,
  source_database
FROM
  dba_capture
WHERE
  purpose = 'XStream Out'
ORDER BY
  capture_name;

-- Capture process: Status
PROMPT <h3>Capture Process: Status</h3>

COL capture_name HEADING 'Capture|Name'
COL status HEADING 'Status'
COL status_change_time HEADING 'Status|Change Time'
COL client_name HEADING 'Outbound|Name'
COL client_status HEADING 'Outbound|Status'
COL first_scn HEADING 'First SCN'
COL start_scn HEADING 'Start SCN'
COL captured_scn HEADING 'Captured SCN'
COL applied_scn HEADING 'Applied SCN'
COL required_checkpoint_scn HEADING 'Required|Checkpoint SCN'
COL error_number HEADING 'Error Number'
COL error_message HEADING 'Error Message'

SELECT   capture_name,   status,   status_change_time,   client_name,   client_status,   first_scn,  start_scn,   captured_scn,   applied_scn,   required_checkpoint_scn,   error_number,    error_message  FROM   dba_capture WHERE purpose = 'XStream Out' ORDER BY  capture_name;

-- Capture process: Statistics
PROMPT <h3>Capture Process: Statistics</h3>

COL capture_name HEADING 'Capture|Name'
COL state HEADING 'State'
COL state_changed_time HEADING 'State|Change Time'
COL startup_time HEADING 'Startup Time'
COL session_restart_scn HEADING 'Session|Restart SCN'
COL capture_lag_seconds HEADING 'Capture Latency|(seconds)'
COL redo_mined_MB HEADING 'Redo Mined (MB)'
COL sga_used_MB HEADING 'SGA Used (MB)'
COL sga_allocated_MB HEADING 'SGA Allocated (MB)'

SELECT
  c.capture_name,
  x.state,
  x.state_changed_time,
  x.startup_time,
  x.session_restart_scn,
  (SYSDATE - x.capture_message_create_time) * 86400 capture_lag_seconds,
  ROUND(x.bytes_of_redo_mined / 1024 / 1024, 2) redo_mined_MB,
  ROUND(x.sga_used / 1024 / 1024) sga_used_MB,
  ROUND(x.sga_allocated / 1024 / 1024) sga_allocated_MB
FROM
  dba_capture c, gv$xstream_capture x
WHERE
  c.capture_name = x.capture_name
  AND c.purpose = 'XStream Out'
ORDER BY c.capture_name;

COL capture_name HEADING 'Capture|Name'
COL total_messages_captured HEADING 'Total|Messages Captured'
COL total_messages_enqueued HEADING 'Total|Messages Enqueued'
COL capture_message_number HEADING 'Last Captured|Message SCN'
COL capture_message_create_time HEADING 'Last Captured|Message Time'
COL enqueue_message_number HEADING 'Last Enqueued|Message SCN'
COL enqueue_message_create_time HEADING 'Last Enqueued|Message Time'
COL available_message_number HEADING 'Last Redo|Flushed SCN'
COL available_message_create_time HEADING 'Last Redo|Flushed Time'

SELECT
  c.capture_name,
  x.total_messages_captured,
  x.total_messages_enqueued,
  x.capture_message_number,
  x.capture_message_create_time,
  x.enqueue_message_number,
  x.enqueue_message_create_time,
  x.available_message_number,
  x.available_message_create_time
FROM
  dba_capture c, gv$xstream_capture x
WHERE
  c.capture_name = x.capture_name
  AND c.purpose = 'XStream Out'
ORDER BY c.capture_name;

-- Capture process: Parameters
PROMPT <h3>Capture Process: Parameters</h3>

COL capture_name HEADING 'Capture Name'
COL parameter HEADING 'Parameter Name'
COL value HEADING 'Parameter Value'
COL set_by_user FORMAT A12 HEADING 'Set By User?'

SELECT
  c.capture_name,
  cp.parameter,
  cp.value,
  cp.set_by_user
FROM
  dba_capture c, dba_capture_parameters cp
WHERE
  c.capture_name = cp.capture_name
  AND c.purpose = 'XStream Out'
  AND
  (
    cp.parameter IN ('MAX_SGA_SIZE', 'PARALLELISM', 'USE_RAC_SERVICE')
    OR
    cp.set_by_user='YES'
  )
ORDER BY
  c.capture_name;

-- Capture process: Registered log files
PROMPT <h3>Capture Process: Registered log files</h3>

COL capture_name HEADING 'Capture Name'
COL thread# HEADING 'Thread'
COL sequence# HEADING 'Sequence'
COL name HEADING 'Name'
COL first_scn HEADING 'First SCN'
COL first_time HEADING 'First Time'
COL next_scn HEADING 'Next SCN'
COL next_time HEADING 'Next Time'
COL dictionary_begin FORMAT A10 HEADING 'Dictionary|Begin'
COL dictionary_end FORMAT A10 HEADING 'Dictionary|End'
COL purgeable FORMAT A9 HEADING 'Purgeable'

SELECT
  c.capture_name,
  l.thread#,
  l.sequence#,
  l.name,
  l.first_scn,
  l.first_time,
  l.next_scn,
  l.next_time,
  l.dictionary_begin,
  l.dictionary_end,
  l.purgeable
FROM
  dba_capture c, dba_registered_archived_log l
WHERE
  c.capture_name = l.consumer_name
  AND c.purpose = 'XStream Out'
ORDER BY
  l.dictionary_begin, l.dictionary_end, c.capture_name, l.first_scn;

-- Capture process: Open transactions
PROMPT <h3>Capture Process: Open transactions</h3>

COL component_name HEADING 'Capture Name'
COL xid HEADING 'XID'
COL cumulative_message_count HEADING 'Cumulative|Message Count'
COL first_message_number HEADING 'First|Message SCN'
COL first_message_time HEADING 'First|Message Time'
COL last_message_number HEADING 'Last|Message SCN'
COL last_message_time HEADING 'Last|Message Time'

SELECT
  t.component_name,
  t.xidusn || '.' || t.xidslt || '.' || t.xidsqn xid,
  t.cumulative_message_count,
  t.first_message_number,
  t.first_message_time,
  t.last_message_number,
  t.last_message_time
FROM
  gv$xstream_transaction t
WHERE
  t.component_type = 'CAPTURE'
ORDER BY
  t.component_name;

--------------
-- LogMiner --
--------------
PROMPT <hr>
PROMPT <h2><a name="LogMiner">LogMiner</a></h2>

-- LogMiner: Status
PROMPT <h3>LogMiner: Status</h3>

COL inst_id HEADING 'Instance ID'
COL session_id HEADING 'Session ID'
COL session_name HEADING 'Session Name'
COL session_state FORMAT A13 HEADING 'Session State'
COL capture_name HEADING 'Capture Name'
COL db_name HEADING 'DB Name'
COL reset_scn HEADING 'Reset SCN'
COL reset_time HEADING 'Reset Time'
COL spill_scn HEADING 'Spill SCN'
COL low_mark_scn HEADING 'Low|Watermark SCN'
COL checkpoint_interval HEADING 'Checkpoint Interval'

SELECT
  s.inst_id,
  s.session_id,
  s.session_name,
  s.session_state,
  c.capture_name,
  s.db_name,
  s.reset_scn,
  s.reset_time,
  s.spill_scn,
  s.low_mark_scn,
  s.checkpoint_interval
FROM
  gv$logmnr_session s, dba_capture c
WHERE c.capture_name = s.session_name
  AND c.purpose = 'XStream Out'
ORDER BY
  s.inst_id,
  c.capture_name;

-- LogMiner: Statistics
PROMPT <h3>LogMiner: Statistics</h3>

COL inst_id HEADING 'Instance ID'
COL session_id HEADING 'Session ID'
COL capture_name HEADING 'Capture Name'
COL used_mem_MB HEADING 'Used Memory (MB)'
COL max_mem_MB HEADING 'Max Memory (MB)'
COL used_mem_pct HEADING 'Used Memory (%)'
COL available_txn HEADING 'Available Txns'
COL available_committed_txn HEADING 'Available|Committed Txns'

SELECT
  s.inst_id,
  s.session_id,
  c.capture_name,
  round(s.used_memory_size / 1024 / 1024, 2) used_mem_MB,
  round(s.max_memory_size / 1024 / 1024, 2) max_mem_MB,
  round((s.used_memory_size / s.max_memory_size) * 100, 2) used_mem_pct,
  s.available_txn,
  s.available_committed_txn
FROM
  gv$logmnr_session s, dba_capture c
WHERE c.capture_name = s.session_name
  AND c.purpose = 'XStream Out'
ORDER BY
  s.inst_id,
  c.capture_name;

---------------------
-- Outbound Server --
---------------------
PROMPT <hr>
PROMPT <h2><a name="Outbound Server">Outbound Server</a></h2>

-- Outbound Server: General
PROMPT <h3>Outbound Server: General</h3>

COL server_name HEADING 'Outbound Name'
COL status HEADING 'Status'
COL connect_user HEADING 'Connect User'
COL capture_name HEADING 'Capture Name'
COL capture_user HEADING 'Capture User'
COL queue_name HEADING 'Queue Name'
COL source_database HEADING 'Source Database'
COL source_root_name HEADING 'Source Root Name'
COL lcrid_version HEADING 'LCR ID Version'

SELECT server_name, status,  connect_user,  capture_name,  capture_user,  queue_owner || '.' || queue_name queue_name,  source_database,  source_root_name,  lcrid_version FROM dba_xstream_outbound ORDER BY server_name;

-- Outbound Server: Progress
PROMPT <h3>Outbound Server: Progress</h3>

COL server_name HEADING 'Outbound Name'
COL processed_low_position HEADING 'Processed Low Position'
COL processed_low_scn HEADING 'Process Low SCN'
COL oldest_position HEADING 'Oldest Position'
COL oldest_scn HEADING 'Oldest SCN'

SELECT
  server_name,
  processed_low_position,
  processed_low_scn,
  oldest_position,
  oldest_scn
FROM
  dba_xstream_outbound_progress
ORDER BY
  server_name;

-- Outbound Server: Statistics
PROMPT <h3>Outbound Server: Statistics</h3>

COL inst_id HEADING 'Instance ID'
COL server_name HEADING 'Outbound Name'
COL state HEADING 'State'
COL startup_time HEADING 'Startup Time'
COL xid HEADING 'XID'
COL total_transactions_sent HEADING 'Total|Transactions Sent'
COL total_messages_sent HEADING 'Total|LCRs Sent'
COL send_time HEADING 'Last Sent|LCR Time'
COL last_sent_message_number HEADING 'Last Sent|LCR SCN'
COL last_sent_message_create_time HEADING 'Last Sent|LCR Creation Time'
COL last_sent_position HEADING 'Last Sent|LCR Position'

SELECT
  inst_id,
  server_name,
  state,
  startup_time,
  xidusn || '.' || xidslt || '.' || xidsqn xid,
  total_transactions_sent,
  total_messages_sent,
  send_time,
  last_sent_message_number,
  last_sent_message_create_time,
  last_sent_position
FROM
  gv$xstream_outbound_server
ORDER BY
  inst_id,
  server_name;

----------------------
-- Apply Components --
----------------------
PROMPT <hr>
PROMPT <h2><a name="Apply Components">Apply Components</a></h2>

-- Apply: General
PROMPT <h3>Apply: General</h3>

COL apply_name HEADING 'Apply Name'
COL apply_user HEADING 'Apply User'
COL queue_name HEADING 'Queue Name'
COL rule_set_name HEADING 'Positive|Ruleset'
COL negative_rule_set_name HEADING 'Negative|Ruleset'

SELECT
  apply_name,
  apply_user,
  queue_owner || '.' || queue_name queue_name,
  CASE
    WHEN rule_set_name IS NOT NULL THEN rule_set_owner || '.' || rule_set_name
    ELSE NULL
  END rule_set_name,
  CASE
    WHEN negative_rule_set_name IS NOT NULL THEN negative_rule_set_owner || '.' || negative_rule_set_name
    ELSE NULL
  END negative_rule_set_name
FROM
  dba_apply
WHERE
  purpose = 'XStream Out'
ORDER BY
  apply_name;

-- Apply: Status
PROMPT <h3>Apply: Status</h3>

COL apply_name HEADING 'Apply Name'
COL status HEADING 'Status'
COL status_change_time HEADING 'Status|Change Time'
COL error_number HEADING 'Error Number'
COL error_message HEADING 'Error Message'

SELECT
  apply_name,
  status,
  status_change_time,
  error_number,
  error_message
FROM
  dba_apply a
WHERE
  purpose = 'XStream Out'
ORDER BY
  apply_name;

-- Apply: Parameters
PROMPT <h3>Apply: Parameters</h3>

COL apply_name HEADING 'Apply Name'
COL parameter HEADING 'Parameter Name'
COL value HEADING 'Parameter Value'
COL set_by_user FORMAT A12 HEADING 'Set By User?'

SELECT
  a.apply_name,
  ap.parameter,
  ap.value,
  ap.set_by_user
FROM
  dba_apply a, dba_apply_parameters ap
WHERE
  a.apply_name = ap.apply_name
  AND a.purpose = 'XStream Out'
  AND
  (
    ap.parameter IN
    ('MAX_SGA_SIZE', 'PARALLELISM',
    'TXN_AGE_SPILL_THRESHOLD', 'TXN_LCR_SPILL_THRESHOLD')
    OR
    ap.set_by_user='YES'
  )
ORDER BY
  a.apply_name;

-- Apply: Open transactions
PROMPT <h3>Apply: Open transactions</h3>

COL inst_id HEADING 'Instance ID'
COL component_name HEADING 'Apply Name'
COL xid HEADING 'XID'
COL cumulative_message_count HEADING 'Cumulative|Message Count'
COL total_message_count HEADING 'Total|Message Count'
COL first_message_number HEADING 'First|Message SCN'
COL first_message_time HEADING 'First|Message Time'
COL last_message_number HEADING 'Last|Message SCN'
COL last_message_time HEADING 'Last|Message Time'

SELECT
  inst_id,
  component_name,
  xidusn || '.' || xidslt || '.' || xidsqn xid,
  cumulative_message_count,
  total_message_count,
  first_message_number,
  first_message_time,
  last_message_number,
  last_message_time
FROM
  gv$xstream_transaction
WHERE
  component_type = 'APPLY'
ORDER BY
  inst_id,
  component_name;

-- Apply: Open transactions
PROMPT <h3>Apply: Spilled transactions</h3>

COL apply_name HEADING 'Apply Name'
COL xid HEADING 'XID'
COL first_scn HEADING 'First Message|SCN'
COL first_message_create_time HEADING 'First Message|Create Time'
COL message_count HEADING 'Spilled Messages'

SELECT
  apply_name,
  xidusn || '.' || xidslt || '.' || xidsqn xid,
  first_scn,
  first_message_create_time,
  message_count
FROM
  dba_apply_spill_txn
ORDER BY
  apply_name;

-- Apply Reader: Statistics
PROMPT <h3>Apply Reader: Statistics</h3>

COL inst_id HEADING 'Instance ID'
COL apply_name HEADING 'Apply Name'
COL state HEADING 'State'
COL total_messages_dequeued HEADING 'Total|Messages Dequeued'
COL total_messages_spilled HEADING 'Total|Messages Spilled'
COL dequeue_time HEADING 'Last LCR|Dequeue Time'
COL dequeued_message_number HEADING 'Last LCR|Dequeue SCN'
COL dequeued_message_create_time HEADING 'Last Dequeued LCR|Source Time'
COL apply_reader_latency HEADING 'Reader Latency|(seconds)'
COL sga_used_MB HEADING 'SGA Used (MB)'
COL sga_allocated HEADING 'SGA Allocated (MB)'
COL total_in_memory_lcrs HEADING 'Total|In-Memory LCRs'

SELECT
  inst_id,
  apply_name,
  state,
  total_messages_dequeued,
  total_messages_spilled,
  dequeue_time,
  dequeued_message_number,
  dequeued_message_create_time,
  (dequeue_time - dequeued_message_create_time) * 86400 apply_reader_latency,
  round(sga_used / 1024 / 1024, 2) sga_used_MB,
  round(sga_allocated / 1024 / 1024, 2) sga_allocated_MB,
  total_in_memory_lcrs
FROM
  gv$xstream_apply_reader
ORDER BY
  inst_id,
  apply_name;

-- Apply Server: Statistics
PROMPT <h3>Apply Server: Statistics</h3>

COL inst_id HEADING 'Instance ID'
COL apply_name HEADING 'Apply Name'
COL apply# HEADING 'Apply|Process Number'
COL server_id HEADING 'Parallel|Server Number'
COL state HEADING 'State'
COL xid HEADING 'XID'
COL apply_time HEADING 'Last Message|Apply Time'
COL applied_message_number HEADING 'Last Message|SCN'
COL applied_message_create_time HEADING 'Last Message|Source Time'
COL last_apply_position HEADING 'Last Message|Position'

SELECT
  inst_id,
  apply_name,
  apply#,
  server_id,
  state,
  xidusn || '.' || xidslt || '.' || xidsqn xid,
  apply_time,
  applied_message_number,
  applied_message_create_time,
  last_apply_position
FROM
  gv$xstream_apply_server
ORDER BY
  inst_id,
  apply_name;

-----------
-- Rules --
-----------
PROMPT <hr>
PROMPT <h2><a name="Rules">Rules</a></h2>

-- Rules: Capture process
PROMPT <h3>Rules: Capture process</h3>

COL streams_name HEADING 'Capture Name'
COL streams_rule_type HEADING 'Streams|Rule Type'
COL rule_set_name HEADING 'Ruleset|Name'
COL rule_set_type HEADING 'Ruleset|Type'
COL rule_name HEADING 'Rule Name'
COL rule_type HEADING 'Rule Type'
COL rule_condition HEADING 'Rule Condition'
COL schema_name HEADING 'Schema Name'
COL object_name HEADING 'Object Name'
COL source_database HEADING 'Source|Database'
COL source_root_name HEADING 'Source|Root Name'
COL source_container_name HEADING 'Source|Container Name'

SELECT
  streams_name,
  streams_rule_type,
  rule_set_owner || '.' || rule_set_name rule_set_name,
  rule_set_type,
  rule_owner || '.' || rule_name rule_name,
  rule_type,
  CAST(rule_condition AS VARCHAR2(4000)) rule_condition,
  schema_name,
  object_name,
  source_database,
  source_root_name,
  source_container_name
FROM
  dba_xstream_rules
WHERE
  streams_type = 'CAPTURE'
ORDER BY
  streams_name;

-- Rules: Outbound server
PROMPT <h3>Rules: Outbound server</h3>

COL streams_name HEADING 'Outbound Name'
COL streams_rule_type HEADING 'Streams|Rule Type'
COL rule_set_name HEADING 'Ruleset|Name'
COL rule_set_type HEADING 'Ruleset|Type'
COL rule_name HEADING 'Rule Name'
COL rule_type HEADING 'Rule Type'
COL rule_condition HEADING 'Rule Condition'
COL schema_name HEADING 'Schema Name'
COL object_name HEADING 'Object Name'
COL source_database HEADING 'Source|Database'
COL source_root_name HEADING 'Source|Root Name'
COL source_container_name HEADING 'Source|Container Name'

SELECT
  streams_name,
  streams_rule_type,
  rule_set_owner || '.' || rule_set_name rule_set_name,
  rule_set_type,
  rule_owner || '.' || rule_name rule_name,
  rule_type,
  CAST(rule_condition AS VARCHAR2(4000)) rule_condition,
  schema_name,
  object_name,
  source_database,
  source_root_name,
  source_container_name
FROM
  dba_xstream_rules
WHERE
  streams_type = 'APPLY'
ORDER BY
  streams_name;

-----------
-- Queue --
-----------
PROMPT <hr>
PROMPT <h2><a name="Queue">Queue</a></h2>

-- Queue: Buffered Queue
PROMPT <h3>Queue: Buffered Queue</h3>

COL inst_id HEADING 'Instance ID'
COL queue_name HEADING 'Queue Name'
COL queue_state HEADING 'Queue State'
COL num_msgs HEADING 'Total|Messages'
COL spill_msgs HEADING 'Spilled|Messages'
COL cnum_msgs HEADING 'Cumulative|Total Messages'
COL cspill_msgs HEADING 'Cumulative|Spilled Messages'
COL spill_ratio HEADING 'Spill Ratio'
COL queue_size_KB HEADING 'Queue Size (KB)'

SELECT
  inst_id,
  queue_name,
  queue_state,
  num_msgs,
  spill_msgs,
  cnum_msgs,
  cspill_msgs,
  (cspill_msgs / DECODE(cnum_msgs, 0, 1, cnum_msgs) * 100) spill_ratio,
  round(queue_size / 1024, 2) queue_size_KB
FROM
  gv$buffered_queues
ORDER BY
  inst_id,
  queue_name;

------------------
-- Streams Pool --
------------------
PROMPT <hr>
PROMPT <h2><a name="Streams Pool">Streams Pool</a></h2>

-- Streams Pool: Statistics
PROMPT <h3>Streams Pool: Statistics</h3>

COL inst_id HEADING 'Instance Id'
COL total_allocated_MB HEADING 'Total Allocated (MB)'
COL current_size_MB HEADING 'Current Size (MB)'
COL sga_target_MB HEADING 'SGA Target Size (MB)'
COL shrink_phase HEADING 'Shrink Phase'
COL advice_disabled HEADING 'Advice Disabled'

SELECT
  inst_id,
  round(total_memory_allocated / 1024 / 1024, 2) total_allocated_MB,
  round(current_size / 1024 / 1024, 2) current_size_MB,
  round(sga_target_value / 1024 / 1024, 2) sga_target_MB,
  shrink_phase,
  advice_disabled
FROM
  gv$streams_pool_statistics
ORDER BY
  inst_id;

-- Streams Pool: Size advice
PROMPT <h3>Streams Pool: Size advice</h3>

COL inst_id HEADING 'Instance Id'
COL streams_pool_size_for_estimate HEADING 'Pool Size|Estimate'
COL streams_pool_size_factor HEADING 'Pool Size|Factor'
COL estd_spill_count HEADING 'Estimated|Spill Count'
COL estd_spill_time HEADING 'Estimated|Spill Time'
COL estd_unspill_count HEADING 'Estimated|Unspill Count'
COL estd_unspill_time HEADING 'Estimated|Unspill Time'

SELECT
  inst_id,
  streams_pool_size_for_estimate,
  streams_pool_size_factor,
  estd_spill_count,
  estd_spill_time,
  estd_unspill_count,
  estd_unspill_time
FROM
  gv$streams_pool_advice
ORDER BY
  inst_id;

--------------
-- Redo Log --
--------------
PROMPT <hr>
PROMPT <h2><a name="Redo Log">Redo Log</a></h2>

-- Redo Log: Summary
PROMPT <h3>Redo Log: Summary</h3>

COL purgeable_yes_count HEADING 'Purgeable|Yes'
COL purgeable_no_count HEADING 'Purgeable|No'
COL min_modified_time HEADING 'Modified Time|Min'
COL max_modified_time HEADING 'Modified Time|Max'

SELECT
  count(CASE WHEN PURGEABLE = 'YES' THEN 1 END) purgeable_yes_count,
  count(CASE WHEN PURGEABLE = 'NO' THEN 1 END) purgeable_no_count,
  min(MODIFIED_TIME) min_modified_time,
  max(MODIFIED_TIME) max_modified_time
FROM
  dba_registered_archived_log;

------------
-- Alerts --
------------
PROMPT <hr>
PROMPT <h2><a name="Alerts">Alerts</a></h2>

-- Alerts: In last 7 days
PROMPT <h3>Alerts: In last 7 days</h3>

COL message_type HEADING 'Message Type'
COL creation_time HEADING 'Creation Time'
COL module_id HEADING 'Module'
COL reason HEADING 'Reason'
COL suggested_action HEADING 'Suggested|Action'
COL resolution FORMAT A10 HEADING 'Resolution'

SELECT
  message_type,
  creation_time,
  module_id,
  reason,
  suggested_action,
  resolution
FROM
  dba_alert_history
WHERE
  message_group IN ('XStream')
  AND trunc(creation_time) >= sysdate - 7
ORDER BY
  creation_time;

-------------------
-- Miscellaneous --
-------------------
PROMPT <hr>
PROMPT <h2><a name="Miscellaneous">Miscellaneous</a></h2>

-- Miscellaneous: XStream administrators
PROMPT <h3>Miscellaneous: XStream administrators</h3>

COL username HEADING 'Username'
COL privilege_type FORMAT A14 HEADING 'Privilege Type'
COL grant_select_privileges FORMAT A17 HEADING 'Grant|Select Privileges'
COL create_time HEADING 'Create Time'

SELECT
  *
FROM
  dba_xstream_administrator;

-- Miscellaneous: XStream sessions
PROMPT <h3>Miscellaneous: XStream sessions</h3>

COL inst_id HEADING 'Instance|ID'
COL sess HEADING 'Session' format a20
COL logon_time HEADING 'Logon|Time' 
COL action HEADING 'Action' format a10
COL status HEADING 'Status'  format a10
COL username HEADING 'Username'  format a10
COL module HEADING 'Module'  format a10
COL process HEADING 'OS Client|Process ID'
COL program HEADING 'OS|Program'  format a10
COL server FORMAT A11 HEADING 'Server|Type'  format a10
COL event HEADING 'Event'  format a10
COL last_call_et HEADING 'Last Call|Elapsed Time'

SELECT   inst_id,  sid || '.' || serial# sess,  logon_time,  action,  status,  username,  module,  process,  program,  server,  event,  last_call_et FROM gv$session WHERE   module LIKE 'XStream%' ORDER BY inst_id;

-- Miscellaneous: Long running transactions
PROMPT <h3>Miscellaneous: Long running transactions</h3>

COL inst_id HEADING 'Instance|ID'
COL sess HEADING 'Session'
COL xid HEADING 'XID'
COL status HEADING 'Status'
COL start_scnb HEADING 'Start|SCNB'
COL start_scnw HEADING 'Start|SCNW'
COL duration HEADING 'Duration'
COL username HEADING 'Username'
COL module HEADING 'Module'
COL program HEADING 'Program'
COL terminal HEADING 'Terminal'

SELECT
  t.inst_id,
  s.sid || '.' || s.serial# sess,
  t.xidusn||'.'||t.xidslot||'.'||t.xidsqn xid,
  t.status,
  t.start_scnb,
  t.start_scnw,
  (SYSDATE - t.start_date) * 1440 duration,
  s.username,
  s.module,
  s.program,
  s.terminal
FROM
  gv$transaction t,
  gv$session s
WHERE t.addr = s.taddr
AND (SYSDATE - t.start_date) * 1440 > 30
ORDER BY
  t.inst_id;

SET HEADING OFF
select 'Report generated on instance: ' || instance_name || ' at time: ' || sysdate FROM v$instance;

prompt </body>
prompt </html>

SPOOL OFF
EXIT
