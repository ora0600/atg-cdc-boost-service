Start advisor

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
SQL> spool 
SQL> exec UTL_RPADV.SHOW_STATS;
LEGEND
<statistics>= <capture>|<replicat> [ <queue> <psender> <preceiver> <queue> ] <apply>|<extract> <bottleneck>
<capture>   = '|<C>' <name> <msgs captured/sec> <msgs enqueued/sec> <latency>
                    'LMR' <idl%> <flwctrl%> <topevt%> <topevt>
                    'LMP' (<parallelism>) <idl%> <flwctrl%> <topevt%> <topevt>
                    'LMB' <idl%> <flwctrl%> <topevt%> <topevt>
                    'CAP' <idl%> <flwctrl%> <topevt%> <topevt>
                    'CAP+PS' <msgs sent/sec> <bytes sent/sec> <latency> <idl%> <flwctrl%> <topevt%> <topevt>
<apply>     = '|<A>' <name> <msgs applied/sec> <txns applied/sec> <latency>
                    'PS+PR' <idl%> <flwctrl%> <topevt%> <topevt>
                    'APR' <idl%> <flwctrl%> <topevt%> <topevt>
                    'APC' <idl%> <flwctrl%> <topevt%> <topevt>
                    'APS' (<parallelism>) <idl%> <flwctrl%> <topevt%> <topevt>
<extract>   = '|<E>' <name> <msgs sent/sec> <bytes sent/sec> <latency> <idl%> <flwctrl%> <topevt%> <topevt>
<replicat>  = '|<R>' <name> <msgs recd/sec> <bytes recd/sec> <idl%> <flwctrl%> <topevt%> <topevt>
<queue>     = '|<Q>' <name> <msgs enqueued/sec> <msgs spilled/sec> <msgs in queue>
<psender>   = '|<PS>' <name> <msgs sent/sec> <bytes sent/sec> <latency> <idl%> <flwctrl%> <topevt%> <topevt>
<preceiver> = '|<PR>' <name> <idl%> <flwctrl%> <topevt%> <topevt>
<bottleneck>= '|<B>' <name> <sub_name> <sessionid> <serial#> <topevt%> <topevt>


OUTPUT
PATH 1 RUN_ID 1 RUN_TIME 2025-AUG-13 12:10:24 CCA N
|<C> CONFLUENT_XOUT1 5.2 0.8 0 LMP (0) CAP 0% "" |<Q> "C##GGADMIN"."Q$_XOUT_1" 0.8 0.01 0 |<A> XOUT 0.4 0.2 0 PS+PR 0% "" APR  APC  APS (2) 0% "" |<B> NO BOTTLENECK IDENTIFIED


PATH 1 RUN_ID 2 RUN_TIME 2025-AUG-13 12:10:31 CCA N
|<C> CONFLUENT_XOUT1 102 0.25 1 LMP (0) CAP 0% "" |<Q> "C##GGADMIN"."Q$_XOUT_1" 0.25 0.01 0 |<A> XOUT 0.01 0.01 0 PS+PR 0% "" APR  APC  APS (2) 0% "" |<B> NO BOTTLENECK IDENTIFIED
