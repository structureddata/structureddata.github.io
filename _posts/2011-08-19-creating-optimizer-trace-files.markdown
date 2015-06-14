---
author: Greg Rahn
comments: true
date: 2011-08-19T04:17:09.000Z
layout: post
slug: creating-optimizer-trace-files
title: 'Creating Optimizer Trace Files '
wp_id: 1501
wp_categories:
  - 11gR1
  - 11gR2
  - Execution Plans
  - Optimizer
  - Oracle
  - Troubleshooting
wp_tags:
  - '10053'
  - Optimizer
  - trace
---

Many Oracle DBA's are probably familiar with what Optimizer trace files are and likely know how to create them.  When I say "Optimizer trace" more than likely you think of event 10053, right?  SQL code like this probably is familiar then:

```
alter session set tracefile_identifier='MY_10053';
alter session set events '10053 trace name context forever';
select /* hard parse comment */ * from emp where ename = 'SCOTT';
alter session set events '10053 trace name context off';
```

In 11g, a new diagnostic events infrastructure was implemented and there are various levels of debug output that you can control for sql compilation. `ORADEBUG` shows us the hierarchy.

```
SQL> oradebug doc component SQL_Compiler

  SQL_Compiler                    SQL Compiler
    SQL_Parser                    SQL Parser (qcs)
    SQL_Semantic                  SQL Semantic Analysis (kkm)
    SQL_Optimizer                 SQL Optimizer
      SQL_Transform               SQL Transformation (kkq, vop, nso)
        SQL_MVRW                  SQL Materialized View Rewrite
        SQL_VMerge                SQL View Merging (kkqvm)
        SQL_Virtual               SQL Virtual Column (qksvc, kkfi)
      SQL_APA                     SQL Access Path Analysis (apa)
      SQL_Costing                 SQL Cost-based Analysis (kko, kke)
        SQL_Parallel_Optimization SQL Parallel Optimization (kkopq)
    SQL_Code_Generator            SQL Code Generator (qka, qkn, qke, kkfd, qkx)
      SQL_Parallel_Compilation    SQL Parallel Compilation (kkfd)
      SQL_Expression_Analysis     SQL Expression Analysis (qke)
      SQL_Plan_Management         SQL Plan Managment (kkopm)
    MPGE                          MPGE (qksctx)
```

My personal preference for Optimizer tracing is to stick with the most detailed level, in this case `SQL_Compiler` vs. just `SQL_Optimizer`.

Given that, we can do the following in 11g:

```
alter session set tracefile_identifier='MY_SQL_Compiler_TRACE';
alter session set events 'trace [SQL_Compiler.*]';
select /* hard parse comment */ * from emp where ename = 'SCOTT';
alter session set events 'trace [SQL_Compiler.*] off';
```

One of the big drawbacks of using the 10053 event or the SQL_Compiler event are that two things need to happen: 1) you have to have the SQL text and 2) a hard parse needs to take place (so there is actually sql compilation). What if you want to get an Optimizer trace file for a statement already executed in your database and is in the cursor cache? Chances are you know how to do #1 & #2 but it's kind of a pain, right? Even more of a pain if the query is pages of SQL or you don't have the application schema password, etc.

In 11gR2 (11.2) there was a procedure added to `DBMS_SQLDIAG` called `DUMP_TRACE`.  The `DUMP_TRACE` procedure didn't make the [`DBMS_SQLDIAG` documentation](http://download.oracle.com/docs/cd/E11882_01/appdev.112/e16760/d_sqldiag.htm) but here is the declaration:

```
-- $ORACLE_HOME/rdbms/admin/dbmsdiag.sql
-------------------------------- dump_trace ---------------------------------
-- NAME: 
--     dump_trace - Dump Optimizer Trace
--
-- DESCRIPTION:
--     This procedure dumps the optimizer or compiler trace for a give SQL 
--     statement identified by a SQL ID and an optional child number. 
--
-- PARAMETERS:
--     p_sql_id          (IN)  -  identifier of the statement in the cursor 
--                                cache
--     p_child_number    (IN)  -  child number
--     p_component       (IN)  -  component name
--                                Valid values are Optimizer and Compiler
--                                The default is Optimizer
--     p_file_id         (IN)  -  file identifier
------------------------------------------------------------------------------
PROCEDURE dump_trace(
              p_sql_id         IN varchar2,
              p_child_number   IN number   DEFAULT 0,
              p_component      IN varchar2 DEFAULT 'Optimizer',
              p_file_id        IN varchar2 DEFAULT null);
```

As you can see, you can specify either Optimizer or Compiler as the component name which is the equivalent of the `SQL_Compiler` or `SQL_Optimizer` events.  Conveniently you can use `P_FILE_ID` to add a trace file identifier to your trace file.  The four commands used above can be simplified to just a single call.  For example:

```
SQL> begin
  2    dbms_sqldiag.dump_trace(p_sql_id=>'6yf5xywktqsa7',
  3                            p_child_number=>0,
  4                            p_component=>'Compiler',
  5                            p_file_id=>'MY_TRACE_DUMP');
  6  end;
  7  /

PL/SQL procedure successfully completed.
```

If we look at the trace file we can see that `DBMS_SQLDIAG.DUMP_TRACE` added in a comment `/* SQL Analyze(1443,0) */` and did the hard parse for us (Thanks!).  

```
Enabling tracing for cur#=9 sqlid=as9bkjstppk0a recursive
Parsing cur#=9 sqlid=as9bkjstppk0a len=91 
sql=/* SQL Analyze(1443,0) */ select /* hard parse comment */ * from emp where ename = 'SCOTT'
End parsing of cur#=9 sqlid=as9bkjstppk0a
Semantic Analysis cur#=9 sqlid=as9bkjstppk0a
OPTIMIZER INFORMATION

******************************************
----- Current SQL Statement for this session (sql_id=as9bkjstppk0a) -----
/* SQL Analyze(1443,0) */ select /* hard parse comment */ * from emp where ename = 'SCOTT'
----- PL/SQL Stack -----
----- PL/SQL Call Stack -----
  object      line  object
  handle    number  name
0x16fd3a368       145  package body SYS.DBMS_SQLTUNE_INTERNAL
0x16fd3a368     12085  package body SYS.DBMS_SQLTUNE_INTERNAL
0x18e7fead8      1229  package body SYS.DBMS_SQLDIAG
0x16fdbddd0         1  anonymous block
*******************************************
```

Hopefully you don't find yourself having to get too many Optimizer Trace Dumps, but if you do and you're on 11.2, the hard work has been done for you.

### Footnote

Due to a bug in `DBMS_ASSERT`, you will need to specify a value for `P_COMPONENT`.  If you leave it `NULL`, it will error like such:

```
SQL> begin
  2    dbms_sqldiag.dump_trace(p_sql_id=>'6yf5xywktqsa7',
  3                            p_child_number=>0,
  4                            p_component=>NULL,
  5                            p_file_id=>'MY_TRACE_DUMP');
  6  end;
  7  /
begin
*
ERROR at line 1:
ORA-44003: invalid SQL name
ORA-06512: at 'SYS.DBMS_ASSERT', line 160
ORA-06512: at 'SYS.DBMS_SQLDIAG', line 1182
ORA-06512: at line 2
```
