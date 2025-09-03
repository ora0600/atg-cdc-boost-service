# Generic POC Plan – How Customers Test the Confluent Oracle XStream CDC Connector

Following tests are covered here:
1. [Deploy Connector](#1-deploy-connector): Setting up Oracle XStream to Kafka with CDB, Non-CDB on RAC or Single Instance Databases
2. [Initial Load only](#2-initial-load-only): This special use case is to show that only read-only should be transfered to Kafka and a workaround for Ad-hoc Snapshots
3. [DML changes](#3-dml-changes): After creation and initial load make changes to the table (DML operations) and validate if those changes reflect in the topic.
4. [Add multiple tables](#4-add-multiple-tables): Evaluate, if we can add multiple tables in single connector
5. [Add multiple tables with different owner](#5-add-multiple-tables-with-different-owner): Evaluate, if we can add multiple tables with different owner’s in the single connector
6. [one capture serves two outbound servers](#6-one-capture-serves-two-outbound-servers): Include multiple tables for capture whether multiple capture process/xstream outbound servers are required.
7. [Pause and stop capture and xstream outbound server](#7-pause-and-stop-capture-and-xstream-outbound-server)
8. [Switch redo logs](#8-switch-redo-logs): Switching the redo log will generate archive logs; then resume or start the capture/XStream server to verify whether it continues from the archives.
9. [Alter capture to start from specific scn](#9-alter-capture-to-start-from-specific-scn)
10. [Alter connector to pick from prior scn](#10-alter-connector-to-pick-from-prior-scn)
11. [Stop db/disable/enable archives and steps to restart capture/xstream outbound server and connector required during maintenance.](#11-stop-dbdisableenable-archives-and-steps-to-restart-capturexstream-outbound-server-and-connector-required-during-maintenance)
12. [Long running transaction](#12-long-running-transaction): Test case with long running transactions 
13. [delete archive logs](#13-delete-archive-logs): Test case: What is happening if archive logs are deleted
14. [Abrupt or normal shut down of source database and check the connector](#14-abrupt-or-normal-shut-down-of-source-database-and-check-the-connector)
15. [Any parameter to set at capture level to make sure it doesn’t consume much memory while extract/replicate.](#15-any-parameter-to-set-at-capture-level-to-make-sure-it-doesnt-consume-much-memory-while-extractreplicate)
16. [Need to explore the monitoring of sessions of those connectors and any specific monitoring which needs our attention need to specify by Confluent.](#16-need-to-explore-the-monitoring-of-sessions-of-those-connectors-and-any-specific-monitoring-which-needs-our-attention-need-to-specify-by-confluent)


# 1. Deploy Connector 
Setting up Oracle XStream to Kafka with CDB, Non-CDB on RAC or Single Instance Databases.
Deployment scripts for NON-CDB and CDB database for RAC and Single Instance DBs are listed [here](https://github.com/ora0600/atg-cdc-boost-service/tree/main/in-flight). The boost-Service will create specific for the customer

## best practices during POC

For each POC, I would recommend that you run direct after setup is deployed (DB Outbound Server and Confluent Connector) the Oracle Performance Advisor, see [slide deck Page 51](landing-flight/Deep-Dive-Operations_Oracle-XStream-CDC-Connector-Maintenace-and-Operation-from-Confluent-ATG-Customer-facing.pdf). The XStream Replication Performance Advisor belongs to the XStream license you will get from the Confluent Connector. Therefore no speicla license is needed for our opinion.

> [!IMPORTANT]
> But, please check with Oracle if you have to run a specific Oracle License for this advisor.


Start from time to time the Replication Performance Advisor, Script can be found [here](https://github.com/ora0600/atg-cdc-boost-service/blob/main/landing-flight/monitoring/start_replication_advisor.sql)

```bash
cd $ORACLE_HOME/rdbms/admin
-- login as GG Admin
sqlplus c##ggadmin@XE
-- Load Advisor
SQL> @utlrpadv.sql
-- To collect the current XStream performance statistics once
SQL> exec UTL_RPADV.COLLECT_STATS;
-- To monitor continually start 
-- SQL> exec UTL_RPADV.START_MONITORING
SQL> set serveroutput on
SQL> exec UTL_RPADV.SHOW_STATS;
OUTPUT
# PATH 1 RUN_ID 1 RUN_TIME 2025-AUG-26 13:16:43 CCA N|<C> CONFLUENT_XOUT1 1 0.01 2 LMP (0) CAP 0% "" |<Q> "C##GGADMIN"."Q$_XOUT_1"0.01 0.01 0 |<A> XOUT 0.4 0.2 0 PS+PR 0% "" PR  APC  APS (2) 0% "" |<B> NO BOTTLENECK IDENTIFIED

# PATH 1 RUN_ID 2 RUN_TIME 2025-AUG-26 13:16:50 CCA N|<C> CONFLUENT_XOUT1 102 1.25 2 LMP (0) CAP 0% "" |<Q> "C##GGADMIN"."Q$_XOUT_1" 1.25 0.01 0 |<A> XOUT 0.5 0.25 0 PS+PR 0%"" APR  APC  APS (2) 0% "" |<B> NO BOTTLENECK IDENTIFIED
```

You can check again and again, if there are some bottlenecks during POC execution.

## RAC special instructions

Follow Oracle Documentation [here](https://docs.oracle.com/en/database/oracle/oracle-database/19/xstrm/xstream-out-concepts.html#GUID-A058CE29-4D13-4EB2-ACDE-29DC6B7F2CDE).
Oracle recommends that you configure Oracle RAC database clients to use the SCAN to connect to the database instead of configuring the tnsnames.ora file. See [here](https://docs.oracle.com/en/database/oracle/oracle-database/18/rilin/about-connecting-to-an-oracle-rac-database-using-scans.html).
How to setup database connections with SCAN addresses is documented [here](https://docs.oracle.com/en/database/oracle/oracle-database/18/rilin/how-database-connections-are-created-when-using-scans.html#GUID-DDA82589-44DB-4681-B0BC-32898D3083BA). The documentation uses EZCONNECT method.

### Confluent Connector properties

`database.service.name`
Name of the database service to which to connect. In a multitenant container database, this is the service used to connect to the container database (CDB). **For Oracle Real Application Clusters (RAC), use the service created by Oracle XStream.**

* Type: string
* Valid Values: Must match the regex ^([a-zA-Z][a-zA-Z0-9$#._]*)*$
* Importance: high

Configure the `database.hostname` property to the Oracle RAC database SCAN address.
See documentation for [Confluent Cloud](https://docs.confluent.io/cloud/current/connectors/cc-oracle-xstream-cdc-source/cc-oracle-xstream-cdc-source.html#connect-to-an-oracle-real-application-cluster-rac-database) or [Confluent Platform](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/getting-started.html#connect-to-an-oracle-real-application-cluster-rac-database) Connector.

### Database 

On the database side you need to add use_rac_service see [Confluent Documentation](https://docs.confluent.io/cloud/current/connectors/cc-oracle-xstream-cdc-source/oracle-xstream-cdc-setup-includes/prereqs-validation.html#capture-changes-from-oracle-rac).

```bash
SQL> BEGIN
  DBMS_CAPTURE_ADM.SET_PARAMETER(
    capture_name => '<CAPTURE_NAME>',
    parameter    => 'use_rac_service',
    value        => 'Y');
END;
/
```

### What if one instances of the RAC crashed?

Confluent[documentation](https://docs.confluent.io/cloud/current/connectors/cc-oracle-xstream-cdc-source/oracle-xstream-cdc-setup-includes/prereqs-validation.html#capture-changes-from-oracle-rac) says:
`If the current owner instance of the queue becomes unavailable, ownership of the queue is automatically transferred to another instance in the cluster. The capture process and the outbound server are restarted automatically on the new owner instance. The connector will restart and attempt to reconnect to the cluster using the configured connection properties.`

And Oracle [documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/xstrm/xstream-out-concepts.html#GUID-A058CE29-4D13-4EB2-ACDE-29DC6B7F2CDE) says:
`If the value for the capture process parameter use_rac_service is set to Y, then each capture process is started and stopped on the owner instance for its ANYDATA queue, even if the start or stop procedure is run on a different instance. Also, a capture process follows its queue to a different instance if the current owner instance becomes unavailable. The queue itself follows the rules for primary instance and secondary instance ownership....If the owner instance for a queue table containing a queue used by a capture process becomes unavailable, then queue ownership is transferred automatically to another instance in the cluster. In addition, if the capture process was enabled when the owner instance became unavailable, then the capture process is restarted automatically on the new owner instance. If the capture process was disabled when the owner instance became unavailable, then the capture process remains disabled on the new owner instance...f the owner instance for a queue table containing a queue used by an outbound server becomes unavailable, then queue ownership is transferred automatically to another instance in the cluster. Also, an outbound server will follow its queue to a different instance if the current owner instance becomes unavailable. The queue itself follows the rules for primary instance and secondary instance ownership. In addition, if the outbound server was enabled when the owner instance became unavailable, then the outbound server is restarted automatically on the new owner instance. If the outbound server was disabled when the owner instance became unavailable, then the outbound server remains disabled on the new owner instance.` 

## Set up each component on its own

As you have learned the `DBMS_XSTREAM_ADM.CREATE_OUTBOUND` will create the complete process of an XStream Outbound Process. This includes logminer, capture, apply, queue, outbound components.
You can setup each components separatly be following these [instructions](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/examples.html#create-a-capture-process-and-an-outbound-server-starting-from-a-specific-scn).


## POC Step evaluation

- [ ]: Outbound Server successfully deployed
- [ ]: (optional: XStream process components successfully deployed manually/separaty)
- [ ]: XStream CDC Connector sucessfully deployed
- [ ]: Monitoring during POC activated

# 2. Initial Load only 
This specific use case demonstrates transferring read-only data to Kafka and provides a workaround for the lack of ad-hoc snapshots.

## Read-Only setup

1. This setup is quite specific. Initially, we only require a full refresh of the database tables into Kafka from time to time, serving as a read-only copy. From there, you can apply transformations using Flink SQL and later run analytics in your analytical data warehouse, such as Databricks. In this scenario, real-time streaming data is not needed. You will find this kind of use case in **forensic accounting analysis**.

2. Another use case is when you want to add additional tables to an existing CDC process. Currently, it is not possible to perform an initial load afterward, since ad-hoc snapshots are not yet supported (but will be available soon). This solution addresses both cases.

The build logic is as followed:
- you will configure a new Outbound Server for an existing table. This table is only a placeholder and should not be used in the connector include list
- Then you create a connector with a different include list, these tables you want to transform to Kafka for read-only.
- The connector will do a snapshot of the included tables because this is done not over outbound server.
- (optional for 2.) And then you can add the new tables to the old outbound server and those new tables have already the initial load

Create a fake outbound server with an existing table:

```bash
-- create a dummy table as application user in DB
sqlplus ordermgmt/kafka@XEPDB1
SQL> create table cmtest (nr number);
SQL> insert into cmtest values (1);
SQL> commit;
SQL> connect c##ggadmin@XE
SQL> DECLARE
    tables  DBMS_UTILITY.UNCL_ARRAY;
    schemas  DBMS_UTILITY.UNCL_ARRAY;
BEGIN
	schemas(1)	:= NULL;
	tables(1)	:= 'C##GGADMIN.CMTEST';
	DBMS_XSTREAM_ADM.CREATE_OUTBOUND(
    capture_name          =>  'fake_confluent_xout1',
    server_name           =>  'fake_xout',
    source_container_name =>  'XEPDB1',   
    table_names           =>  tables,
    schema_names          =>  schemas,
    comment               => 'Confluent Xstream CDC Connector for read-only' );
END;
/

```

Deploy the connector with the following config file, with enabling flatten SMT, because before and after values do not make sense here:

```JSON
{
            "name": "XSTREAMCDCFAKE0",
            "config":{
              "connector.class":                                      "io.confluent.connect.oracle.xstream.cdc.OracleXStreamSourceConnector",
              "task.max":                                             1,
              "database.hostname":                                    "##oracle_host##",
              "database.port":                                        1521,
              "database.user":                                        "C##GGADMIN",
              "database.password":                                    "Confluent12!",
              "database.dbname":                                      "XE",
              "database.service.name":                                "XE",
              "database.pdb.name":                                    "XEPDB1",
              "database.processor.licenses":                          4,
              "database.out.server.name":                             "FAKE_XOUT",
              "table.include.list":                                   "ORDERMGMT[.](ORDER_ITEMS|ORDERS|EMPLOYEES|PRODUCTS|CUSTOMERS|INVENTORIES|PRODUCT_CATEGORIES|CONTACTS|NOTES|WAREHOUSES|LOCATIONS|COUNTRIES|REGIONS)",
              "topic.prefix":                                         "pdb1fake",
              "snapshot.mode":                                        "initial", 
              "snapshot.fetch.size":                                  10000, 
              "snapshot.max.threads":                                 4,
              "query.fetch.size":                                     10000,
              "max.queue.size":                                       65536,
              "max.batch.size":                                       16384,
              "producer.override.batch.size":                         204800,
              "producer.override.linger.ms":                          50,
              "heartbeat.interval.ms":                                300000,              
              "schema.history.internal.kafka.bootstrap.servers":      "##bootstrap##",
              "schema.history.internal.kafka.sasl.jaas.config":       "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"##connectorkey##\" password=\"##connectorsecret##\";",
              "schema.history.internal.kafka.security.protocol":      "SASL_SSL",
              "schema.history.internal.kafka.sasl.mechanism":         "PLAIN",
              "schema.history.internal.consumer.security.protocol":   "SASL_SSL",
              "schema.history.internal.consumer.ssl.endpoint.identification.algorithm": "https",
              "schema.history.internal.consumer.sasl.mechanism":     "PLAIN",
              "schema.history.internal.consumer.sasl.jaas.config":   "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"##connectorkey##\" password=\"##connectorsecret##\";",
              "schema.history.internal.producer.security.protocol":  "SASL_SSL",
              "schema.history.internal.producer.ssl.endpoint.identification.algorithm": "https",
              "schema.history.internal.producer.sasl.mechanism":     "PLAIN",
              "schema.history.internal.producer.sasl.jaas.config":   "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"##connectorkey##\" password=\"##connectorsecret##\";",
              "schema.history.internal.kafka.topic":                  "__orcl-schema-changes_fake.XEPDB1",
              "confluent.topic.replication.factor":                   "3",
              "topic.creation.default.replication.factor":            "3",
              "topic.creation.default.partitions":                    "1",
              "confluent.topic.bootstrap.servers":                    "##bootstrap##",
              "confluent.topic.sasl.jaas.config":                     "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"##connectorkey##\" password=\"##connectorsecret##\";",
              "confluent.topic.security.protocol":                    "SASL_SSL",
              "confluent.topic.sasl.mechanism":                       "PLAIN",
              "key.converter":                                        "io.confluent.connect.avro.AvroConverter",
              "value.converter":                                      "io.confluent.connect.avro.AvroConverter",
              "output.key.format":                                    "AVRO",
              "output.data.format":                                   "AVRO",
              "key.converter.schema.registry.basic.auth.user.info":   "##srkey:srsecret##",
              "key.converter.schema.registry.url":                    "##srrestpoint##",          
              "value.converter.schema.registry.basic.auth.user.info": "##srkey:srsecret##",
              "value.converter.schema.registry.url":                  "##srrestpoint##",          
              "enable.metrics.collection":                            "true",
              "transforms":                                           "format",
              "transforms.format.type":                               "io.debezium.transforms.ExtractNewRecordState",
              "transforms.format.delete.handling.mode":               "rewrite",
              "transforms.format.delete.tombstone.handling.mode":     "drop",
              "transforms.format.add.fields":                         "op:operation_type,source.ts_us:operation_time,ts_ns:sortable_sequence",
              "transforms.format.add.fields.prefix":                  "db_"
            }
}
```

The connector will create tables and load the data into the topics. Wait till Snasphot is finished.

Check status of outbound:

```bash
SQL> connect c##ggadmin@XE
SQL> COLUMN SERVER_NAME FORMAT A15
COLUMN CAPTURE_NAME FORMAT A15
COLUMN CONNECT_USER FORMAT A20
COLUMN SOURCE_DATABASE FORMAT A20
COLUMN QUEUE_OWNER FORMAT A15
COLUMN QUEUE_NAME FORMAT A15
COLUMN PARAMETER FORMAT A40
COLUMN VALUE FORMAT A40
COLUMN STATE FORMAT A20
COLUMN TABLESPACE_NAME FORMAT A20
COLUMN FILE_NAME FORMAT A50
COLUMN CREATE_DATE FORMAT A28
COLUMN START_TIME FORMAT A28
COLUMN COMMITTED_DATA_ONLY heading "COMMITTED|DATA|ONLY" FORMAT A9
SELECT SERVER_NAME, 
       CAPTURE_NAME, 
       QUEUE_OWNER, 
       QUEUE_NAME, 
       CONNECT_USER, 
       SOURCE_DATABASE,
       STATUS,
       CREATE_DATE,
       COMMITTED_DATA_ONLY,
       START_SCN,
       START_TIME
FROM DBA_XSTREAM_OUTBOUND;
# Output                                                                                                           COMMITTED
#SERVER_NAME CAPTURE_NAME    QUEUE_OWNER QUEUE_NAME      CONNECT_USER SOURCE_DB STATUS   CREATE_DATE        ONLY      START_SCN START_TIME
#----------- --------------- ----------- --------------- ------------ --------- -------- ------------------ --------- ---------- ------------------ 
#FAKE_XOUT   FAKE_CONFLUENT_ C##GGADMIN  Q$_FAKE_XOUT_69 C##GGADMIN   XEPDB1    ATTACHED 27-AUG-25 06.26.31 YES          4121457 27-AUG-25 06.26.23
#            XOUT1
```
You should now all the topics loaded with initial data name in the structure `FAKEXEPDB1.ORDERMGMT.<TABLE_NAME>`.
Afterwards you can drop the Outbound Server

```bash
SQL> connect c##ggadmin@XE
SQL> BEGIN
  DBMS_XSTREAM_ADM.DROP_OUTBOUND(
    server_name => 'fake_xout');
END;
/
```

And shutdown the fake connector.

If you want to run the initial load to an existing outbound now, please follow these [instructions](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/examples.html#add-tables-to-the-capture-set), but please sure in such case, that here we do need flatten the schema structure. 

## POC Step evaluation

- [ ]: Outbound Server successfully deployed
- [ ]: XStream CDC Connector sucessfully deployed
- [ ]: Initial load successfully loaded into topics
- [ ]: Drop Outbound and Shutdown connector successfully
- [ ]: (Optional) add table to existing Outbound Server worked successfully


# 3. DML changes:
After creation and initial load make changes to the table (DML operations) and validate if those changes reflect in the topic.
Should be straight forward. DB Setup is given.

## Outbound Server created as ADMIN:

```bash
sqlplus c##ggadmin@XE
SQL> DECLARE
  tables  DBMS_UTILITY.UNCL_ARRAY;
  schemas DBMS_UTILITY.UNCL_ARRAY;
BEGIN
    tables(1)   := 'ORDERMGMT.ORDERS';
    ...        
    DBMS_XSTREAM_ADM.CREATE_OUTBOUND(
      capture_name          =>  'confluent_xout1',
      server_name           =>  'xout',
      source_container_name =>  'XEPDB1',   
      table_names           =>  tables,
      schema_names          =>  schemas,
      comment               => 'Confluent Xstream CDC Connector' );
-- set retention
    DBMS_CAPTURE_ADM.ALTER_CAPTURE(
      capture_name => 'confluent_xout1',
      checkpoint_retention_time => 1
    );
END;
/
-- STREAM POOL SIZE should be 1024, in XE 256
BEGIN
  DBMS_XSTREAM_ADM.SET_PARAMETER(
    streams_type => 'capture',
    streams_name => 'confluent_xout1',
    parameter    => 'max_sga_size',
    value        => '256');
END;
/
BEGIN
  DBMS_XSTREAM_ADM.SET_PARAMETER(
    streams_type => 'apply',
    streams_name => 'xout',
    parameter    => 'max_sga_size',
    value        => '256');
END;
/
```

## Connector started:
```bash
{
            "name": "XSTREAMCDC0",
            "config":{
              "connector.class":                                      "io.confluent.connect.oracle.xstream.cdc.OracleXStreamSourceConnector",
              "task.max":                                             1,
...
              "enable.metrics.collection":                            "true"
            }
}
```

check if Connector is attached to XOUT Server

```bash
SQL> SELECT CAPTURE_NAME, STATUS FROM ALL_XSTREAM_OUTBOUND WHERE SERVER_NAME = 'XOUT';
```

## Change DML
Best way would be to write a short procedure call like run order inserts, see [code](https://github.com/ora0600/confluent-new-cdc-connector/blob/main/oraclexe21c/docker/scripts/06_data_generator.sql)

```sql
SQL> Connect sys/confluent123@XEPDB1 as sysdba
-- check which tables are run outbound support
SQL> SELECT OWNER, OBJECT_NAME, SUPPORT_MODE
 FROM DBA_XSTREAM_OUT_SUPPORT_MODE
 ORDER BY OBJECT_NAME;
SQL> connect ordermgmt/kafka@ORCPDB1 
SQL> begin
   produce_orders;
end;
/

-- as c##ggadmin check current transaction
-- # Current transaction
SQL> SELECT SERVER_NAME,
       XIDUSN ||'.'|| 
       XIDSLT ||'.'||
       XIDSQN "Transaction ID",
       COMMITSCN,
       COMMIT_POSITION,
       LAST_SENT_POSITION,
       MESSAGE_SEQUENCE
  FROM V$XSTREAM_OUTBOUND_SERVER;
-- Statistics, what was sent
SQL> SELECT SERVER_NAME,
       TOTAL_TRANSACTIONS_SENT,
       TOTAL_MESSAGES_SENT,
       (BYTES_SENT/1024)/1024 BYTES_SENT,
       (ELAPSED_SEND_TIME/100) ELAPSED_SEND_TIME,
       LAST_SENT_MESSAGE_NUMBER,
       TO_CHAR(LAST_SENT_MESSAGE_CREATE_TIME,'HH24:MI:SS MM/DD/YY') 
          LAST_SENT_MESSAGE_CREATE_TIME
  FROM V$XSTREAM_OUTBOUND_SERVER;
-- # Capture latency
SQL> SELECT CAPTURE_NAME,
      ((SYSDATE - CAPTURE_MESSAGE_CREATE_TIME)*86400) LATENCY_SECONDS
FROM V$XSTREAM_CAPTURE;
```

You can stop the connector via UI or API call.

```bash
curl -s -X PUT -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/pause | jq
```

Wait a while and write down the offset. Then resume the connector. The connector should continue, from the last offset.

```bash
curl -s -X PUT -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/resume | jq
```

Try to update, insert and delete a message

```sql
sqlplus ordermgmt/kafka@XEPDB1
SQL> delete from orders where order_id = 44;
SQL> commit;
```

You should see in topic viewner

```json
  "payload": {
    "before": {
      "ORDER_ID": 44,
      "CUSTOMER_ID": 2,
      "STATUS": "Pending",
      "SALESMAN_ID": 55,
      "ORDER_DATE": 1487548800000
    },
    "after": null,
```

Check logs and topic message viewer.

## POC Step evaluation

- [ ]: Outbound and connector still runnning 
- [ ]: Changed data visible in topics


# 4. Add multiple tables

Evaluate, if we can add multiple tables in a single connector.

Follow the intructions from Confluent Documentation: See [multiple tables](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/examples.html#capture-multiple-tables)
Follow the intructions from Confluent Documentation: : See [Add tables to the capture set](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/examples.html#add-tables-to-the-capture-set)

If you add tables to an existing capture process, please note that ad-hoc snapshots for newly added tables are not yet supported (as of August 2025). A workaround for this is described in [2. Use case: Initial Load only](#2-initial-load-only). The Confluent Oracle CDC XStream Connector will support adhoc snapshots very soon. 

## POC Step evaluation

- [ ]: Add multiples tables first sucessfully
- [ ]: Add tables to existing capture set (without initial data load)
- [ ]: Add tables to existing capture set (with initial data load, see [2. Use case: Initial Load only](#2-initial-load-only)


# 5. Add multiple tables with different owner 

Evaluate, if we can add multiple tables with different owner’s in the single connector

Follow the intructions from Confluent Documentation: See [multiples tables and schemas](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/examples.html#capture-multiple-tables-and-schemas)
Follow the intructions from Confluent Documentation: See [remove table from capture set](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/examples.html#remove-tables-from-the-capture-set)

## POC Step evaluation

- [ ]: Add multiples tables with different schema first sucessfully
- [ ]: remove tables from existing capture set successfully

# 6. one capture serves two outbound servers 

Include multiple tables for capture whether multiple capture process/xstream outbound servers are required.

Scale on bigger tables and divide outbound servers. One outbound server for bigger tables and another one for all the others. 
Follow these instructions for add a new Outbound Server: See [example](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/examples.html#add-an-outbound-server-to-an-existing-capture-process)

This sample create one capture and outbound server. And add an additional outbound server to the existing capture process with existing queue.

## POC Step evaluation

- [ ]: First outbound was created successfully
- [ ]: a second outbound server to an existing capture created successfully.

# 7. Pause and stop capture and xstream outbound server

It’s easy to pause and resume the connector. The question is: what happens if the capture or XStream outbound server is paused or stopped?

```bash
sqlplus c##ggadmin@XE
SQL> BEGIN
 DBMS_XSTREAM_ADM.STOP_OUTBOUND(
 server_name => 'xout');
END;
/
# Infos, when servers started
SQL>SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
# start outbound again
SQL> BEGIN
 DBMS_XSTREAM_ADM.START_OUTBOUND(
 server_name => 'xout');
END;
/
```

You can do the same with the capture process:

```bash
# Get XOUT 
SQL> SELECT CAPTURE_NAME, STATUS FROM ALL_XSTREAM_OUTBOUND WHERE SERVER_NAME = 'XOUT';
# stop capture
SQL> BEGIN
 DBMS_CAPTURE_ADM.STOP_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/
# Infos, when servers started
SQL> SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
```

no changes are visible in topic viewer. No error in connect log.

Start capture again:

```bash
# start capture
SQL> BEGIN
 DBMS_CAPTURE_ADM.START_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/
# Infos, when servers started
SQL> SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
```

Data is again visible in topic viewer. And data will continue from last offset.

## POC Step evaluation

- [ ]: Start and stop Outbound Server successfully
- [ ]: Start and stop Capture Server successfully
- [ ]: Data is continued to flow from last offset, data is complete


# 8. Switch redo logs

Switching the redo log will generate archive logs; then resume or start the capture/XStream server to verify whether it continues from the archives.

Connect as sysdba and switch log file:

```sql
sqlplus sys/confluent123@XE as sysdba
SQL> ALTER SYSTEM SWITCH LOGFILE;
```

No error in connect log. Everything is working stable. The order flow is not broken, every 5 seconds a record will add to topic ``.
Now stop the capture server, switch log and start capture again.

```sql
-- stop capture
SQL> connect c##ggadmin@XE
SQL> BEGIN
 DBMS_CAPTURE_ADM.STOP_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/
```

If you have a look on the topic viewer the last was `2025-08-27T09:46:03.149Z`.
Continue with switch log, and start capture afterwards:

```bash
SQL> connect sys/confluent123@XE as sysdba
SQL> ALTER SYSTEM SWITCH LOGFILE;
SQL> connect c##ggadmin@XE
SQL> BEGIN
 DBMS_CAPTURE_ADM.START_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/
```

No errors in log file. Connector stopped az 9650 offset and continued with 9443 offset. All missing records where inserted into topic at time `2025-08-27T09:48:20.986Z`.
Now, stop outbound, switch log and start again:

```bash
SQL> connect c##ggadmin@XE
#- stop outbound 
SQL> BEGIN
 DBMS_XSTREAM_ADM.STOP_OUTBOUND(
 server_name => 'xout');
END;
/
```

Last insert was `2025-08-27T09:49:48.974Z at offset 9695`.
Continue with switch log:

```bash
SQL> connect sys/confluent123@XE as sysdba
SQL> ALTER SYSTEM SWITCH LOGFILE;
SQL> ALTER SYSTEM SWITCH LOGFILE;
SQL> connect c##ggadmin@XE
# start outbound 
SQL> BEGIN
 DBMS_XSTREAM_ADM.START_OUTBOUND(
 server_name => 'xout');
END;
/
```

No errors. Stopped at 9695 and continues with offset 9596.

## POC Step evaluation

- [ ]: Log switch, Start and stop caopture Server successfully, no data lost
- [ ]: Log switch, Start and stop Outbound Server successfully, no data lost

# 9. Alter capture to start from specific scn

I assume there is already an outbound server running, and that you plan to stop the capture process and restart it from a specific SCN.
If you want to create a new outbound server starting from a specific SCN, please refer to this [example](https://docs.confluent.io/cloud/current/connectors/cc-oracle-xstream-cdc-source/oracle-xstream-cdc-setup-includes/examples.html#create-a-capture-process-and-an-outbound-server-starting-from-a-specific-scn).


First, how to get a scn of a transaction?

```bash
sqlplus ordermgmt/kafka@XEPDB1
SQL> insert into regions (region_name) values ('East-Europe');
SQL> commit;
SQL> insert into regions (region_name) values ('North-Europe');
SQL> commit;
SQL> connect sys/confluent123@XE as sysdba
SQL> select current_scn from v$database;
 -- after Inserts into region 4257605
```

We will now start the connector with an outbound server. This guy is doing the initial load, and later we do capture back to a SCN and see what is happening.
Start the outbound server first:

Login into Database via ssh in my case `ssh -i ~/keys/cmawsdemoxstream.pem ec2-user@X.X.X.X` and then:

```bash
sqlplus c##ggadmin@ORCLCDB
#Password is Confluent12!
SQL> DECLARE
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
    schemas(1)  := 'ORDERMGMT';        
  DBMS_XSTREAM_ADM.CREATE_OUTBOUND(
    capture_name          =>  'confluent_xout1',
    server_name           =>  'xout',
    source_container_name =>  'XEPDB1',   
    table_names           =>  tables,
    schema_names          =>  schemas,
    comment               => 'Confluent Xstream CDC Connector' );
-- set rentention
    DBMS_CAPTURE_ADM.ALTER_CAPTURE(
      capture_name => 'confluent_xout1',
      checkpoint_retention_time => 7
    );
END;
/
```

Before I start the connector, I do have the following SCNs

```bash
SQL> connect sys/confluent123@XE as sysdba
SQL> select current_scn from v$database;
-- 4257605 before starting the connector
SQL> SELECT capture_name, first_scn, start_scn FROM ALL_CAPTURE where CAPTURE_NAME = 'CONFLUENT_XOUT1';
-- and capture process running first and start SCN = 4171263
```
Now, start the connector. In my case in a container.

```bash
cd ../cdc-connector
# start environment, for Confluent colleques: Shutdown VPN, otherwise the instant client can not be loaded
docker-compose -f docker-compose-cdc-ccloud_new.yml up -d
docker-compose -f docker-compose-cdc-ccloud_new.yml ps
# Are connectors running?
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors | jq
# start connector with correct json config
curl -s -X POST -H 'Content-Type: application/json' --data @cdc_ccloud.json http://localhost:8083/connectors | jq
# Check status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
```

Now the connector is running. If you have a look into topic viewer on topic `xepdb1.ordermgmt.regions` then we have 4 records coming from the initial load. All are tagged with `"op": "r"` which means coming from initial load.
If I do an insert now, we will get a new record in topic viewer.

```bash
SQL> connect ordermgmt/kafka@XEPDB1
-- insert
SQL> insert into regions(region_name) values ('North_Europe');
SQL> commit;
```

A new entry will be visible in topic viewer. The new entry tagged with `"op": "c",`.

Now, I will try to stop capturing and going back to **SCN=4257605**.

```bash
SQL> connect c##ggadmin@XE
# Get XOUT 
SQL> SELECT CAPTURE_NAME, STATUS FROM ALL_XSTREAM_OUTBOUND WHERE SERVER_NAME = 'XOUT';
# Connector is attached.
# stop capture
SQL> BEGIN
 DBMS_CAPTURE_ADM.STOP_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/
# Infos, when servers started and stopped
SQL> SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
```

No changes are visible in topic viewer (see ORDERS flow). Last entry in orders was `2025-08-27T10:04:37.452Z at Offset 9880`. 
No error in connect log. 
I do now insert and store the SCN before that:

```bash
SQL> connect sys/confluent123@XE as sysdba
SQL> select current_scn from v$database;
# Current SCN = 4259324
SQL> connect ordermgmt/kafka@xepdb1
SQL> insert into regions (region_name) values ('South-Europe');
SQL> COMMIT;
```

Before alter the capturing process we need to know the first SCN of the capture process. The Start SCN value must be greater than or equal to the first SCN for the capture process. Also, the capture process must be stopped before resetting its start SCN.

```bash
SQL> connect c##ggadmin@XE
SQL> SELECT capture_name, first_scn, start_scn FROM ALL_CAPTURE where CAPTURE_NAME = 'CONFLUENT_XOUT1';
# CONFLUENT_XOUT1	First: 4171263    Start: 4171263
```

Alter the Capture process to start with **SCN=4257605**, first scn is lower, so altering must work. If the first SCN is not lower, then you need to go with a complete new Outbound server, please follow then these [instructions](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/examples.html#create-a-capture-process-and-an-outbound-server-starting-from-a-specific-scn).

```bash
SQL> BEGIN
  DBMS_CAPTURE_ADM.ALTER_CAPTURE(
    capture_name => 'CONFLUENT_XOUT1',
    start_scn    => 4257605);
END;
/
```

Start again:

```bash
# start capture
SQL> BEGIN
 DBMS_CAPTURE_ADM.START_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/
SQL> SELECT capture_name, first_scn, start_scn FROM ALL_CAPTURE where CAPTURE_NAME = 'CONFLUENT_XOUT1';
# FIRST SCN: 4171263, START_SCN should now be 4257605
# Infos, when servers started
SQL> SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
```

Everything worked fine. Region South-Europe is visible in topic viewer, no errors in connect log so far.

> [!IMPORTANT]
> If the capture process is down for longer time, then Connector failed and stopped: `oracle.streams.StreamsException: ORA-26914: Unable to communicate with XStream capture process "CONFLUENT_XOUT1" from outbound server "XOUT".` In my trial it took **3-4 minutes** till the connector failed. The connector will retry up to three times before stopping and entering a failed state, which requires user intervention to resolve.

Do a restart if the connector failed.

```bash
curl -s -X PUT http://localhost:8083/connectors/XSTREAMCDC0/stop| jq
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
curl -s -X PUT http://localhost:8083/connectors/XSTREAMCDC0/resume | jq 
```

After the connector restart, it is working as expected for new DB changes.
The better way would be to do a controlled maintenance:

1. stop the connector before doing the maintenance 
2. stop capturing, 
3. alter capturing
4. start capturing
5. restart connector

## POC Step evaluation

- [ ]: Stop/Alter/Start the capture to a specific time higher the FIRST_SCN
- [ ]: No data loss 

# 10. Alter connector to pick from prior scn

As mentioned before in case 9, it is easy to start from older SCN, but not lower than FIRST_SCN of capture process.
If you really need to go back in time then you have to stop existing outbound setup and create a new process.

Please shutdown the current outbound server and destroy the connector.

```bash
SQL> connect c##ggadmin@XE
# Stop
SQL> exec DBMS_XSTREAM_ADM.STOP_OUTBOUND(server_name =>  'xout');
# DROP
SQL> exec DBMS_XSTREAM_ADM.DROP_OUTBOUND(server_name =>  'xout');
```

Now you can re-create outbound for a specific SNC. In my case `SCN=4257605`.
Confluent has documented a [Stepy-by-Step Guide](https://docs.confluent.io/cloud/current/connectors/cc-oracle-xstream-cdc-source/oracle-xstream-cdc-setup-includes/examples.html#create-a-capture-process-and-an-outbound-server-starting-from-a-specific-scn)

see my steps:

```bash
# create queue
SQL> BEGIN
  DBMS_XSTREAM_ADM.SET_UP_QUEUE(
    queue_table => 'c##ggadmin.xs_queue_tbl',
    queue_name  => 'c##ggadmin.xs_queue');
END;
/
# Create capture
SQL> BEGIN
  DBMS_CAPTURE_ADM.CREATE_CAPTURE(
    queue_name       => 'c##ggadmin.xs_queue',
    capture_name     => 'xs_capture',
    capture_user     => 'c##ggadmin',
    first_scn        => 4257605,
    start_scn        => 4257605,
    source_database  => 'XEPDB1',
    source_root_name => 'XE',
    capture_class    => 'XStream');
END;
/
# create log dictionary
SQL> exec DBMS_CAPTURE_ADM.BUILD;
# create rules, this time only one table
SQL> BEGIN
  DBMS_XSTREAM_ADM.ADD_TABLE_RULES(
    table_name            => 'ordermgmt.regions',
    streams_type          => 'capture',
    streams_name          => 'xs_capture',
    queue_name            => 'c##ggadmin.xs_queue',
    include_dml           => TRUE,
    include_ddl           => TRUE,
    source_database       => 'XEPDB1',
    source_root_name      => 'XE',
    source_container_name => 'XEPDB1');
END;
/
# add outbound with the same name
SQL> BEGIN
  DBMS_XSTREAM_ADM.ADD_OUTBOUND(
    server_name           => 'xout',
    queue_name            => 'c##ggadmin.xs_queue',
    capture_name          => 'xs_capture',
    include_dml           => FALSE,
    include_ddl           => FALSE,
    source_database       => 'XEPDB1',
    source_root_name      => 'XE',
    source_container_name => 'XEPDB1');
END;
/
# outbound rules
SQL> BEGIN
  DBMS_XSTREAM_ADM.ADD_TABLE_RULES(
    table_name            => 'ordermgmt.regions',
    streams_type          => 'apply',
    streams_name          => 'xout',
    queue_name            => 'c##ggadmin.xs_queue',
    include_dml           => TRUE,
    include_ddl           => TRUE,
    source_database       => 'XEPDB1',
    source_root_name      => 'XE',
    source_container_name => 'XEPDB1');
END;
/
# start capture
SQL> BEGIN
  DBMS_CAPTURE_ADM.START_CAPTURE(
    capture_name => 'xs_capture');
END;
/
# Start outbound
SQL> BEGIN
  DBMS_XSTREAM_ADM.START_OUTBOUND(
    server_name => 'xout');
END;
/
```

Now, you can deploy the connector from UI or API or in my case via terraform as fully-managed connector.
The connector will do a complete initial load of regions table only (because of capture), and get the all the data from START_SCN: 4257605.
I my case I got, 
- REGION_ID 1-8 as initial load op=r
- REGION_ID 7-8 as inserted transaction op=c (North and South)

This is eaxctly expected behaviour of our connector. The connector took the current records and go back to SNC REGION_ID 4257605, and afertwards we did insert North and later Sourch-Europe.


## POC Step evaluation

- [ ]: Create the complete process manually was successfull
- [ ]: Connector was destroyed and re-deployed successfully
- [ ]: Data is sync as expected: complete refresh and 

# 11. Stop db/disable/enable archives and steps to restart capture/xstream outbound server and connector required during maintenance.

I did setup a clean environment for this test case.

Login into database:

```bash
ssh -i ~/keys/cmawsdemoxstream.pem ec2-user@X.X.X.X
sudo docker exec -it oracle19c /bin/bash
sqlplus /nolog
SQL> CONNECT sys/confluent123 AS SYSDBA
SQL> select current_scn from v$database;
# OUTcome: 3697036
```

The go back SCN is now: **3697036**.

Continue with tests: Shutdown, disable archive log, etc.:

```bash
# disable archive log
SQL> shutdown immediate;
SQL> startup mount;
SQL> alter database noarchivelog;
SQL> alter database open;
```

The connector will crash immediately with the command `shutdown immediate` with error `org.apache.kafka.connect.errors.ConnectException: Failed to set session container to XEPDB1` and `Caused by: java.sql.SQLRecoverableException: ORA-12514: TNS:listener does not currently know of service requested in connect descriptor` or error `ORA-26804: Apply "XOUT" is disabled.`. The connector stopped in state **failed**.

Connector details: `Failure: The database is not configured with ARCHIVELOG mode enabled, which is required for this connector to function. Please enable ARCHIVELOG mode in the database and restart the connector.`

Continue with enablement.

```BASH
# enable archive log
SQL> shutdown immediate;
SQL> startup mount;
SQL> alter database archivelog;
SQL> alter database open;
SQL> ALTER SESSION SET CONTAINER=cdb$root;
SQL> ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
SQL> ALTER SESSION SET CONTAINER=XEPDB1;
SQL> ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
# Made Logging asynchronous
SQL> ALTER SESSION SET CONTAINER=cdb$root;
SQL> ALTER SYSTEM SET commit_logging = 'BATCH' CONTAINER=ALL;
SQL> ALTER SYSTEM SET commit_wait = 'NOWAIT' CONTAINER=ALL;
```

Connector still stopped in failed start. OUTBOUND Server aborted as well.

Start Outbound Server:

```bash
SQL> connect c##ggadmin@XE
SQL> BEGIN
 DBMS_XSTREAM_ADM.START_OUTBOUND(
 server_name => 'xout');
END;
/
# Check if everything is started
SQL> SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
```

Restart Connector:

```bash
curl -s -X PUT http://localhost:8083/connectors/XSTREAMCDC0/stop | jq
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
curl -s -X PUT http://localhost:8083/connectors/XSTREAMCDC0/resume | jq 
```

Check what is capturing doing:

```bash
SQL> PROMPT ==== messages captured and enqueued ====
COLUMN CAPTURE_NAME HEADING 'Capture|Process|Name' FORMAT A15
COLUMN STATE HEADING 'STATE' FORMAT A25
COLUMN LATENCY_SECONDS HEADING 'Latency|in|Seconds' FORMAT 999999
COLUMN LAST_STATUS HEADING 'Seconds Since|Last Status' FORMAT 999999
COLUMN CAPTURE_TIME HEADING 'Current|Process|Time'
COLUMN CREATE_TIME HEADING 'Message|Creation Time' FORMAT 999999
COLUMN TOTAL_MESSAGES_CAPTURED HEADING 'Total|captured|Messages' FORMAT 999999
COLUMN TOTAL_MESSAGES_ENQUEUED HEADING 'MessTotalage|Enqueued|Messages' FORMAT 999999

SELECT CAPTURE_NAME,
		STATE,
       ((SYSDATE - CAPTURE_MESSAGE_CREATE_TIME)*86400) LATENCY_SECONDS,
       ((SYSDATE - CAPTURE_TIME)*86400) LAST_STATUS,
       TO_CHAR(CAPTURE_TIME, 'HH24:MI:SS MM/DD/YY') CAPTURE_TIME,       
       TO_CHAR(CAPTURE_MESSAGE_CREATE_TIME, 'HH24:MI:SS MM/DD/YY') CREATE_TIME,
       TOTAL_MESSAGES_CAPTURED,
       TOTAL_MESSAGES_ENQUEUED 
  FROM gV$XSTREAM_CAPTURE;
#OUTPUT:
#Capture                                   Latency               Current                                Total MessTotalage
#Process                                        in Seconds Since Process           Message           captured     Enqueued
#Name            STATE                     Seconds   Last Status Time              Creation Time     Messages     Messages
#--------------- ------------------------- ------- ------------- ----------------- ----------------- -------- ------------
#CONFLUENT_XOUT1 WAITING FOR TRANSACTION        14            13 14:42:09 08/27/25 14:42:08 08/27/25     5110          282
```

Everything looks fine. Do an insert into regions table to see if data is moving into topic.

```bash
SQL> connect ordermgmt/kafka@XEPDB1
SQL> insert into regions (region_name) values ('test4');
SQL> COMMIT;
```

New record is visible in topic `xepdb1.ordermgmt.regions`.

Again, do a controlled maintenance process is the recommendation.

1. stop the connector before doing the maintenance 
2. stop outbound servers
3. do maintenance
4. start ountbound servers
5. restart connector

## POC Step evaluation

- [ ]: Disable archivelog mode successfully
- [ ]: Connector failed as expected
- [ ]: enable archivelog mode, restart Outbound, Connector and see data is flowing.

# 12. Long running transaction

Test case, for long running transactions where we won’t commit and then we move or delete archives from the source and then commit. Check the connector status and data.

Now , I will open three terminal windows, and run uncommited procedure calls. These procedures will insert 600 records in 10 minutes without a commit. We will open three terminals and start procedure and after 10 minutes I do a commit;

```bash
ssh -i ~/keys/cmawsdemoxstream.pem ec2-user@X.X.X.X
sudo docker exec -it oracle21c /bin/bash
sqlplus ordermgmt/kafka@XEPDB1
SQL> execute produce_orders_wo_commit;
# you need to commit manually, the procedure takes exact 10 minutes
SQL> commit;
```

In the meantime you could run [Confluent Diag Script](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/_downloads/6d672a473a3153a88f9c67de5e0b558f/orclcdc_diag.sql) or my [simple xstream report script](https://github.com/ora0600/atg-cdc-boost-service/blob/main/landing-flight/monitoring/simple_xstream_report.sql), to see what is happening in DB.
The connector doesn't care. Connector is in running mode all the time.
If you have self-managed connector running with a metric Dashboard, then you would see:
- The connector start with ms behind source of -1 to 4530 ms (4 sec). This will increase over time (10 min). 
- JVM Heapsize started at 1.8 GB and ends with 1,91 GB. 

So, nothing strange, everything in safe water.


## POC Step evaluation

- [ ]: Start long running transaction
- [ ]: Connector running as expected
- [ ]: All orders are visible in Topic viewer


# 13. delete archive logs 

Test case scenario: What is happening, when the archives are deleted or moved?
In Prod: Huge number of archives gets generated and  moved the archives regularly via cron) while capture process is running what will be the status and how to manage?

If you run on current redolog files you will have no problems. If you have long running transaction which need archive logs then the connector will generate errors.
check in DB:

```bash
sqlplus sys/confluent123@XE as sysdba
SQL> ARCHIVE LOG LIST
# Database log mode              Archive Mode
# Automatic archival             Enabled
# Archive destination            /opt/oracle/homes/OraDBHome21cXE/dbs/arch
# Oldest online log sequence     7
# Next log sequence to archive   9
# Current log sequence           9
```

Check on OS in DB, in my case:

```bash
SQL> !ls -la /opt/oracle/homes/OraDBHome21cXE/dbs
# total 288748
# drwxr-x---. 1 oracle oinstall     16384 Aug 27 14:09 .
# drwxr-x---. 1 oracle oinstall        41 Aug  2  2023 ..
# -rw-r-----. 1 oracle oinstall 176211968 Aug 27 13:43 arch1_2_1143830636.dbf
# -rw-r-----. 1 oracle oinstall  26846208 Aug 27 13:43 arch1_3_1143830636.dbf
# -rw-r-----. 1 oracle oinstall  20538880 Aug 27 13:43 arch1_4_1143830636.dbf
# -rw-r-----. 1 oracle oinstall  11817472 Aug 27 14:00 arch1_5_1143830636.dbf
# -rw-r-----. 1 oracle oinstall      1024 Aug 27 14:00 arch1_6_1143830636.dbf
# -rw-r-----. 1 oracle oinstall  41380864 Aug 27 14:00 arch1_7_1143830636.dbf
# -rw-r-----. 1 oracle oinstall      5632 Aug 27 14:00 arch1_8_1143830636.dbf
# -rw-r-----. 1 oracle oinstall  18841600 Aug 27 14:09 c-3024951340-20250827-00
# and delete all
SQL> !rm /opt/oracle/homes/OraDBHome21cXE/dbs/arch1*.dbf
# chekc again
SQL> !ls -la /opt/oracle/homes/OraDBHome21cXE/dbs
# total 18400
# drwxr-x---. 1 oracle oinstall       38 Aug 27 15:19 .
# drwxr-x---. 1 oracle oinstall       41 Aug  2  2023 ..
# -rw-r-----. 1 oracle oinstall 18841600 Aug 27 14:09 c-3024951340-20250827-00
```

In my case this would not be a problem, because I am working with current redologs. 
This is something what customers can better test in own environment. If an required archive log is missing, then the capture process will get state `WAITING FOR REDO...`.

Before deleting any archive logs please check which ones are required:

```bash
SQL> connect c##ggadmin@XE
SQL> PROMPT ==== Displaying Redo Log Files That Are Required by Each Capture Process ====
COLUMN CONSUMER_NAME HEADING 'Capture|Process|Name' FORMAT A16
COLUMN SOURCE_DATABASE HEADING 'Source|Database' FORMAT A10
COLUMN SEQUENCE# HEADING 'Sequence|Number' FORMAT 99999
COLUMN NAME HEADING 'Required|Archived Redo Log|File Name' FORMAT A60

SELECT r.CONSUMER_NAME,
       r.SOURCE_DATABASE,
       r.SEQUENCE#, 
       r.NAME 
  FROM DBA_REGISTERED_ARCHIVED_LOG r, ALL_CAPTURE c
  WHERE r.CONSUMER_NAME =  c.CAPTURE_NAME AND
        r.NEXT_SCN      >= c.REQUIRED_CHECKPOINT_SCN;  
# no rows selected
```

In my case to archive logs were required that's why I could all of them. To avoid such error please follow the following guide

# How to avoid deleting required archive logs

According to Oracle's documentation, if a capture process is stopped and restarted, then it starts scanning the redo log from the SCN that corresponds to its Required Checkpoint SCN. A capture process needs the redo log file that includes the required checkpoint SCN and all subsequent redo log files.

```bash
set lines 300
PROMPT ==== Capture Process Status and Statistics -REQUIRED_CHECKPOINT_SCN ====
COLUMN CAPTURE_NAME FORMAT A16
SELECT CAPTURE_NAME, STATUS, CAPTURE_TYPE, START_SCN, APPLIED_SCN, REQUIRED_CHECKPOINT_SCN
FROM DBA_CAPTURE
WHERE CAPTURE_NAME IN (SELECT CAPTURE_NAME FROM DBA_XSTREAM_OUTBOUND);
#CAPTURE_NAME     STATUS   CAPTURE_TY  START_SCN APPLIED_SCN REQUIRED_CHECKPOINT_SCN
#---------------- -------- ---------- ---------- ----------- -----------------------
#CONFLUENT_XOUT1  ENABLED  LOCAL         2327839     2429348                 2422468
```

The required checkpoint scn is this sample: 2422468

```Bash
PROMPT ==== Displaying Redo Log Files That Are Required by Each Capture Process ====
COLUMN CONSUMER_NAME HEADING 'Capture|Process|Name' FORMAT A16
COLUMN SOURCE_DATABASE HEADING 'Source|Database' FORMAT A10
COLUMN SEQUENCE# HEADING 'Sequence|Number' FORMAT 99999
COLUMN NAME HEADING 'Required|Archived Redo Log|File Name' FORMAT A60
SELECT r.CONSUMER_NAME,
       r.SOURCE_DATABASE,
       r.SEQUENCE#, 
       r.THREAD#,
       r.NAME, 
       c.REQUIRED_CHECKPOINT_SCN,
       r.NEXT_SCN
  FROM DBA_REGISTERED_ARCHIVED_LOG r, ALL_CAPTURE c
  WHERE r.CONSUMER_NAME =  c.CAPTURE_NAME AND
        r.NEXT_SCN      >= c.REQUIRED_CHECKPOINT_SCN;  
# no rows selected        
```

If the last query results in `no rows selected` then I can delete all archive logs.
I run the query without checking the SCN.

```Bash
PROMPT ==== Displaying Redo Log Files That Are Required by Each Capture Process ====
COLUMN CONSUMER_NAME HEADING 'Capture|Process|Name' FORMAT A16
COLUMN SOURCE_DATABASE HEADING 'Source|Database' FORMAT A10
COLUMN SEQUENCE# HEADING 'Sequence|Number' FORMAT 99999
COLUMN NAME HEADING 'Required|Archived Redo Log|File Name' FORMAT A60
SELECT r.CONSUMER_NAME,
       r.SOURCE_DATABASE,
       r.SEQUENCE#, 
       r.THREAD#,
       r.NAME, 
       c.REQUIRED_CHECKPOINT_SCN,
       r.NEXT_SCN
  FROM DBA_REGISTERED_ARCHIVED_LOG r, ALL_CAPTURE c
  WHERE r.CONSUMER_NAME =  c.CAPTURE_NAME;
#Capture                                         Required
#Process          Source     Sequence            Archived Redo Log
#Name             Database     Number    THREAD# File Name                                                    REQUIRED_CHECKPOINT_SCN   NEXT_SCN
#---------------- ---------- -------- ---------- ------------------------------------------------------------ ----------------------- ----------
#OGG$CAP_ORADB19C ORCLPDB1          8          1 /opt/oracle/product/19c/dbhome_1/dbs/arch1_8_1192789111.dbf                  2311341    2180306
#OGG$CAP_ORADB19C ORCLPDB1          9          1 /opt/oracle/product/19c/dbhome_1/dbs/arch1_9_1192789111.dbf                  2311341    2181564
#CONFLUENT_XOUT1  ORCLPDB1         11          1 /opt/oracle/product/19c/dbhome_1/dbs/arch1_11_1192789111.dbf                 2433426    2327839
#CONFLUENT_XOUT1  ORCLPDB1         12          1 /opt/oracle/product/19c/dbhome_1/dbs/arch1_12_1192789111.dbf                 2433426    2328550  
```        

So, I can delete every archive log (4 in total), and I do that

```bash
ssh -i ~/keys/cmawsdemoxstream.pem ec2-user@X.X.X.X 
sudo docker exec -it oracle19c /bin/bash
rm /opt/oracle/product/19c/dbhome_1/dbs/arch1_8_1192789111.dbf
rm /opt/oracle/product/19c/dbhome_1/dbs/arch1_9_1192789111.dbf 
rm /opt/oracle/product/19c/dbhome_1/dbs/arch1_11_1192789111.dbf
rm /opt/oracle/product/19c/dbhome_1/dbs/arch1_12_1192789111.dbf
```

Archive logs are deleted, check what is happing on capture process

```bash
PROMPT ==== messages captured and enqueued ====
COLUMN CAPTURE_NAME HEADING 'Capture|Process|Name' FORMAT A15
COLUMN STATE HEADING 'STATE' FORMAT A25
COLUMN LATENCY_SECONDS HEADING 'Latency|in|Seconds' FORMAT 999999
COLUMN LAST_STATUS HEADING 'Seconds Since|Last Status' FORMAT 999999
COLUMN CAPTURE_TIME HEADING 'Current|Process|Time'
COLUMN CREATE_TIME HEADING 'Message|Creation Time' FORMAT 999999
COLUMN TOTAL_MESSAGES_CAPTURED HEADING 'Total|captured|Messages' FORMAT 999999
COLUMN TOTAL_MESSAGES_ENQUEUED HEADING 'MessTotalage|Enqueued|Messages' FORMAT 999999

SELECT CAPTURE_NAME,
		STATE,
       ((SYSDATE - CAPTURE_MESSAGE_CREATE_TIME)*86400) LATENCY_SECONDS,
       ((SYSDATE - CAPTURE_TIME)*86400) LAST_STATUS,
       TO_CHAR(CAPTURE_TIME, 'HH24:MI:SS MM/DD/YY') CAPTURE_TIME,       
       TO_CHAR(CAPTURE_MESSAGE_CREATE_TIME, 'HH24:MI:SS MM/DD/YY') CREATE_TIME,
       TOTAL_MESSAGES_CAPTURED,
       TOTAL_MESSAGES_ENQUEUED 
  FROM gV$XSTREAM_CAPTURE;
#Capture                                   Latency               Current                                Total MessTotalage
#Process                                        in Seconds Since Process           Message           captured     Enqueued
#Name            STATE                     Seconds   Last Status Time              Creation Time     Messages     Messages
#--------------- ------------------------- ------- ------------- ----------------- ----------------- -------- ------------
#CONFLUENT_XOUT1 WAITING FOR TRANSACTION         5             4 13:42:29 06/04/25 13:42:28 06/04/25    13911         4409
```

Data is still flowing without any problem. We do not touch any component.

One other suggestion would be to use RMAN to delete the archived redo log files. RMAN does not delete the archived redo log files if required by the capture process, unless disk space is exhausted, in which case it would delete a required archived redo log file also.
However, RMAN always ensures that archived redo log files are backed up before it deletes them. If RMAN deletes an archived redo log file that is required by a capture process, then RMAN records this action in the alert log [Ref](https://docs.oracle.com/en/database/oracle/oracle-database/19/xstrm/troubleshooting-xstream-out.html#GUID-4E6239CC-E633-45B9-8081-A1FEB5A64012).


## POC Step evaluation

- [ ]: Delete archive logs
- [ ]: If you environment is working on redo log, the nothing happening
- [ ]: if you environment is working on these archive logs, then capture process will move to state `WAITING FOR REDO...`


# 14. Abrupt or normal shut down of source database and check the connector

see case 10.

# 15. Any parameter to set at capture level to make sure it doesn’t consume much memory while extract/replicate.

Memory is strong performance enabler. 
**Configure Streams Pool and XStream Memory Limits**: As noted, the Streams pool must be large enough to hold buffered queued messages. You can also control how much of the Streams pool an XStream process will use via the MAX_SGA_SIZE parameters. For the capture process, use [DBMS_CAPTURE_ADM.SET_PARAMETER](https://docs.oracle.com/en/database/oracle/oracle-database/21/arpls/DBMS_CAPTURE_ADM.html#GUID-5A56325D-7613-4FDE-BBB9-0704B990E51F) to set MAX_SGA_SIZE(in MB) if you want to cap or guarantee memory for capture. Similarly, for the outbound server (apply), use DBMS_XSTREAM_ADM.SET_PARAMETER to adjust its MAX_SGA_SIZE. By default these may be “infinite” (i.e., up to what the Streams pool can provide) (XStream Guide ) (XStream Guide ), but it’s good to ensure they are not inadvertently too low. If these are too small, the capture process can hit its memory limit and start spilling to disk or throttling. Oracle documentation suggests using these to control memory per process and to ensure the sum for all capture/apply fits in the Streams pool (XStream Guide ). In high-throughput setups, allowing a capture process to use several hundred MB or a few GB in memory is often necessary.

We set the MAX_SGA_SIZE as followed for a good start:

```Bash
SQL> connect c##ggadmin@XE
SQL> -- STREAM POOL SIZE should be 1024 (1GB) for capture and apply
BEGIN
  DBMS_XSTREAM_ADM.SET_PARAMETER(
    streams_type => 'capture',
    streams_name => 'confluent_xout1',
    parameter    => 'max_sga_size',
    value        => '1024');
END;
/
BEGIN
  DBMS_XSTREAM_ADM.SET_PARAMETER(
    streams_type => 'apply',
    streams_name => 'xout',
    parameter    => 'max_sga_size',
    value        => '1024');
END;
/
```

Please check the parameters for Outbound:

```bash
SQL> PROMPT ==== Displaying the Apply Parameter Settings for an Outbound Server ====
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
# Output
#Outbound Server                                                       Set by
#Name            Parameter                      Value                  User?
#--------------- ------------------------------ ---------------------- ----------
#XOUT            MAX_SGA_SIZE                   1024                    YES  
```

and for Capture:

```bash
SQL> PROMPT ==== Capture Process Parameters ====
COLUMN CAPTURE_NAME HEADING 'Capture|Process|Name' FORMAT A25
COLUMN PARAMETER HEADING 'Parameter' FORMAT A30
COLUMN VALUE HEADING 'Value' FORMAT A10
COLUMN SET_BY_USER HEADING 'Set by|User?' FORMAT A10
 
SELECT c.CAPTURE_NAME,
       PARAMETER,
       VALUE,
       SET_BY_USER
  FROM ALL_CAPTURE_PARAMETERS c, ALL_XSTREAM_OUTBOUND o
  WHERE c.CAPTURE_NAME=o.CAPTURE_NAME
  ORDER BY PARAMETER;
# Output
#Capture
#Process                                                             Set by
#Name                      Parameter                      Value      User?
#------------------------- ------------------------------ ---------- ----------
#CONFLUENT_XOUT1           MAX_SGA_SIZE                   256        YES
```

## POC Step evaluation

- [ ]: please set MAX_SGA_SIZE for capture
- [ ]: please set MAX_SGA_SIZE for apply
- [ ]: check if both parameters are set successfully

# 16. Need to explore the monitoring of sessions of those connectors and any specific monitoring which needs our attention need to specify by confluent.

We have a minium of queries you could against your DB. 

```bash
SQL> connect c##ggadmin@XE
# Sessions
SQL> SELECT /*+PARAM('_module_action_old_length',0)*/ ACTION,
       username, 
       SID,
       SERIAL#,
       PROCESS,
       SUBSTR(PROGRAM,INSTR(PROGRAM,'(')+1,4) PROCESS_NAME
  FROM V$SESSION
  WHERE MODULE ='XStream';
# outbound server
SQL> SELECT SERVER_NAME, 
       CONNECT_USER, 
       CAPTURE_USER, 
       CAPTURE_NAME,
       SOURCE_DATABASE,
       QUEUE_OWNER,
       QUEUE_NAME
  FROM ALL_XSTREAM_OUTBOUND;
# Statistics, what was sent
SQL> SELECT SERVER_NAME,
       TOTAL_TRANSACTIONS_SENT,
       TOTAL_MESSAGES_SENT,
       (BYTES_SENT/1024)/1024 BYTES_SENT,
       (ELAPSED_SEND_TIME/100) ELAPSED_SEND_TIME,
       LAST_SENT_MESSAGE_NUMBER,
       TO_CHAR(LAST_SENT_MESSAGE_CREATE_TIME,'HH24:MI:SS MM/DD/YY') 
          LAST_SENT_MESSAGE_CREATE_TIME
  FROM V$XSTREAM_OUTBOUND_SERVER;
# Capture
SQL> SELECT CAPTURE_NAME, STATUS, CAPTURE_TYPE, START_SCN, APPLIED_SCN, REQUIRED_CHECKPOINT_SCN
FROM DBA_CAPTURE
WHERE CAPTURE_NAME IN (SELECT CAPTURE_NAME FROM DBA_XSTREAM_OUTBOUND);
# capture state
SQL> SELECT CAPTURE_NAME,
		STATE,
       ((SYSDATE - CAPTURE_MESSAGE_CREATE_TIME)*86400) LATENCY_SECONDS,
       ((SYSDATE - CAPTURE_TIME)*86400) LAST_STATUS,
       TO_CHAR(CAPTURE_TIME, 'HH24:MI:SS MM/DD/YY') CAPTURE_TIME,       
       TO_CHAR(CAPTURE_MESSAGE_CREATE_TIME, 'HH24:MI:SS MM/DD/YY') CREATE_TIME,
       TOTAL_MESSAGES_CAPTURED,
       TOTAL_MESSAGES_ENQUEUED 
  FROM gV$XSTREAM_CAPTURE;
# QUEUE STate
SQL> SELECT QUEUE_SCHEMA, QUEUE_NAME, QUEUE_STATE, COUNT(*) AS MESSAGE_COUNT
FROM V$BUFFERED_QUEUES
WHERE QUEUE_NAME IN (SELECT QUEUE_NAME FROM DBA_XSTREAM_OUTBOUND)
GROUP BY QUEUE_SCHEMA, QUEUE_NAME, QUEUE_STATE;
```  

I would recommend to run the [Confluent Diag Script](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/_downloads/6d672a473a3153a88f9c67de5e0b558f/orclcdc_diag.sql) or the [simple XStream report script](https://github.com/ora0600/atg-cdc-boost-service/blob/main/landing-flight/monitoring/simple_xstream_report.sql). You will find more scripts  [here](https://github.com/ora0600/atg-cdc-boost-service/tree/main/landing-flight/monitoring).


## POC Step evaluation

- [ ]: Execute Queries successfully

