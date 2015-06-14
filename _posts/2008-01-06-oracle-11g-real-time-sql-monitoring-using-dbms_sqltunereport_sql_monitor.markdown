---
author: Greg Rahn
comments: true
date: 2008-01-06
layout: post
slug: oracle-11g-real-time-sql-monitoring-using-dbms_sqltunereport_sql_monitor
title: 'Oracle 11g: Real-Time SQL Monitoring Using DBMS_SQLTUNE.REPORT_SQL_MONITOR'
wp_id: 49
wp_categories:
  - 11gR1
  - Execution Plans
  - Oracle
  - Performance
  - SQL Tuning
  - Troubleshooting
wp_tags:
  - DBMS_SQLTUNE.REPORT_SQL_MONITOR
  - oracle 11g
  - Real-Time SQL Monitoring
---

Many times a DBA wants to know where a SQL statement is in its execution plan and where the time is being spent.  There are a few ways to find out this information, but an 11g new feature makes gathering this information extremely easy. Oracle 11g [Real-Time SQL Monitoring](http://download.oracle.com/docs/cd/B28359_01/server.111/b28274/instance_tune.htm#CACGEEIF) allows you to monitor the performance of SQL statements while they are executing as well as see the breakdown of time and resources used for recently completed statements.  It is on by default when `STATISTICS_LEVEL` is set to to `ALL` or `TYPICAL` (the default value) and monitors statements that consume more than 5 seconds of CPU or IO time, as well as any parallel execution (PQ, PDML, PDDL).  One can override the default actions by using the `MONITOR` or `NO_MONITOR` hint.  The [11g Documentation](http://www.oracle.com/pls/db111/homepage) has a [text version of a SQL Monitor Report](http://download.oracle.com/docs/cd/B28359_01/server.111/b28274/instance_tune.htm#CACGEEIF) but the report output can be html, text or xml.

### Real-Time SQL Monitoring Report Walkthrough
To demonstrate the Real-Time SQL Monitoring feature, I started a parallel query and every 60 seconds or so I captured a Real-Time SQL Monitoring report in html format using `DBMS_SQLTUNE.REPORT_SQL_MONITOR`.  Reports 1 through 4 are captures while the query is executing, Report 5 is a post execution capture.  Each of the below links will open in a new window.

- [SQL Monitoring Report 1](/assets/report1.html)
- [SQL Monitoring Report 2](/assets/report2.html)
- [SQL Monitoring Report 3](/assets/report3.html)
- [SQL Monitoring Report 4](/assets/report4.html)
- [SQL Monitoring Report 5](/assets/report5.html)

As you browse through the SQL Monitoring Reports you will see which operation(s) of the execution plan is/are active, how long they have been active, as well as wait events and database time.  You can mouse over each of the colored bars to get more detail.  As the SQL Monitoring Report notes, this query was executed using a DOP of 8, but there were 16 slaves, 2 sets of 8 which act in a producer/consumer pair.  In the SQL Plan Monitoring Details section you can see which operations were performed by each slave set, as well as the QC, by the colors of the Id column.  This report also makes it very easy to see that there was some skew in the work for the first slave set.  Slaves p003 and p004 performed much more IO than the other slaves and it stands out by the length of the colored bars.  The "Active Period" column allows one to see which operations were active, for how long, and at what point of the overall execution.  I feel this report gives a great visualization of the execution and a visual breakdown of DB Time and Wait Activity.  I'm quite certain I will be using this feature frequently when troubleshooting execution plans and as well as db time drill down.

I'm really excited about Real-Time SQL Monitoring's ability to capture the Estimated and Actual number of rows for each row source.  This eliminates the need to run a query with a GATHER_PLAN_STATISTICS hint as I discussed in my post: [Troubleshooting Bad Execution Plans](/2007/11/21/troubleshooting-bad-execution-plans/).

### More Information

There are a few slides on Real-Time SQL Monitoring in the [_DBAs' New Best Friend: Advanced SQL Tuning Features of Oracle Database 11g_](http://www.oracle.com/technology/products/manageability/database/pdf/ow07/sqltune_presentation_ow07.pdf) (starting on page 27) presentation from OOW 2007.  As the presentation mentions, Real-Time SQL Monitoring will also be a part of 11g Enterprise Manager Grid Control.

### Addendum (2008/02/12)

If you want to get a SQL Monitor report for a statement you just ran in your session (similar to `dbms_xplan.display_cursor`) then use this command: 

``` sql
set pagesize 0 echo off timing off linesize 1000 trimspool on trim on long 2000000 longchunksize 2000000
select DBMS_SQLTUNE.REPORT_SQL_MONITOR(
   session_id=>sys_context('userenv','sid'),
   report_level=>'ALL') as report
from dual;
```

Or if you want to generate the EM Active SQL Monitor Report (my recommendation) from any SQL_ID you can use:

``` sql
set pagesize 0 echo off timing off linesize 1000 trimspool on trim on long 2000000 longchunksize 2000000 feedback off
spool sqlmon_4vbqtp97hwqk8.html
select dbms_sqltune.report_sql_monitor(type=>'EM', sql_id=>'4vbqtp97hwqk8') monitor_report from dual;
spool off
```
