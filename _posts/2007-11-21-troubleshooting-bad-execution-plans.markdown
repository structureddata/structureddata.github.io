---
author: Greg Rahn
comments: true
date: 2007-11-21T10:00:12.000Z
layout: post
slug: troubleshooting-bad-execution-plans
title: Troubleshooting Bad Execution Plans
wp_id: 40
wp_categories:
  - Execution Plans
  - Optimizer
  - Oracle
  - Performance
  - SQL Tuning
  - Statistics
  - Troubleshooting
wp_tags:
  - DBMS_STATS
---

One of the most common performance issues DBAs encounter are bad execution plans.  Many try to resolve bad executions plans by setting optimizer related parameters or even hidden underscore parameters.  Some even try to decipher a long and complex 10053 trace in hopes to find an answer.  While changing parameters or analyzing a 10053 trace might be useful for debugging at some point, I feel there is a much more simple way to start to troubleshoot bad execution plans.

### Verify The Query Matches The Business Question

This seems like an obvious thing to do, but I've seen numerous cases where the SQL query does not match the business question being asked.  Do a quick sanity check verifying things like: join columns, group by, subqueries, etc.  The last thing you want to do is consume time trying to debug a bad plan for an improperly written SQL query.  Frequently I've found that this is the case for many of those "_I've never got it to run to completion_" queries.

### What Influences The Execution Plan

I think it's important to understand what variables influence the Optimizer in order to focus the debugging effort.  There are quite a number of variables, but frequently the cause of the problem ones are: (1) non-default optimizer parameters and (2) non-representative object/system statistics.  Based on my observations I would say that the most abused Optimizer parameters are:

- `OPTIMIZER_INDEX_CACHING`
- `OPTIMIZER_INDEX_COST_ADJ`
- `DB_FILE_MULTIBLOCK_READ_COUNT`

Many see setting these as a solution to get the Optimizer to choose an index plan over a table scan plan, but this is problematic in several ways:

- This is a global change to a local problem
- Although it appears to solve one problem, it is unknown how many bad execution plans resulted from this change
- The root cause of why the index plan was not chosen is unknown, just that tweaking parameters gave the desired result
- Using non-default parameters makes it almost impossible to correctly and effectively troubleshoot the root cause

Object and system statistics can have a large influence on execution plans, but few actually take the time to sanity check them during triage.  These statistics exist in views like:

- `ALL_TAB_COL_STATISTICS`
- `ALL_PART_COL_STATISTICS`
- `ALL_INDEXES`
- `SYS.AUX_STATS$`

#### Using `GATHER_PLAN_STATISTICS` With `DBMS_XPLAN.DISPLAY_CURSOR`

As a first step of triage, I would suggest executing the query with a GATHER_PLAN_STATISTICS hint followed by a call to `DBMS_XPLAN.DISPLAY_CURSOR`.  The `GATHER_PLAN_STATISTICS` hint allows for the collection of extra metrics during the execution of the query.  Specifically, it shows us the Optimizer's estimated number of rows (E-Rows) and the actual number of rows (A-Rows) for each row source.  If the estimates are vastly different from the actual, one probably needs to investigate why.  For example:  In the below plan, look at line 8.  The Optimizer estimates 5,899 rows and the row source actually returns 5,479,000 rows.  If the estimate is off by three orders of magnitude (1000), chances are the plan will be sub-optimal. Do note that with Nested Loop Joins you need to multiply the Starts column by the E-Rows column to get the A-Rows values (see line 10). 

``` sql
select /*+ gather_plan_statistics */ ... from ... ;
select * from table(dbms_xplan.display_cursor(null, null, 'ALLSTATS LAST'));

------------------------------------------------------------------------------------------
|  Id | Operation                              | Name         | Starts | E-Rows | A-Rows |
------------------------------------------------------------------------------------------
|   1 | SORT GROUP BY                          |              |     1  |      1 | 1      |
|*  2 |  FILTER                                |              |     1  |        | 1728K  |
|   3 |   NESTED LOOPS                         |              |     1  |      1 | 1728K  |
|*  4 |    HASH JOIN                           |              |     1  |      1 | 1728K  |
|   5 |     PARTITION LIST SINGLE              |              |     1  |   6844 | 3029   |
|*  6 |      INDEX RANGE SCAN                  | PROV_IX13    |     1  |   6844 | 3029   |
|   7 |     PARTITION LIST SINGLE              |              |     1  |   5899 | 5479K  |
|*  8 |      TABLE ACCESS BY LOCAL INDEX ROWID | SERVICE      |     1  |   5899 | 5479K  |
|*  9 |       INDEX SKIP SCAN                  | SERVICE_IX8  |     1  |   4934 | 5479K  |
|  10 |    PARTITION LIST SINGLE               |              |  1728K |      1 | 1728K  |
|* 11 |     INDEX RANGE SCAN                   | CLAIM_IX7    |  1728K |      1 | 1728K  |
------------------------------------------------------------------------------------------
```

#### Using The `CARDINALITY` Hint

Now that I've demonstrated how to compare the cardinality estimates to the actual number of rows, what are the debugging options?  If one asserts that the Optimizer will choose the optimal plan if it can accurately estimate the number of rows, one can test using the not so well (un)documented `CARDINALITY` hint.  The `CARDINALITY` hint tells the Optimizer how many rows are coming out of a row source.  The hint is generally used like such: 


``` sql
select /*+ cardinality(a 100) */ * from dual a;

--------------------------------------------------------------------------
| Id  | Operation         | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |      |   100 |   200 |     2   (0)| 00:00:01 |
|   1 |  TABLE ACCESS FULL| DUAL |   100 |   200 |     2   (0)| 00:00:01 |
--------------------------------------------------------------------------
```

In this case I told the Optimizer that `DUAL` would return 100 rows (when in reality it returns 1 row) as seen in the Rows column from the autotrace output.  The `CARDINALITY` hint is one tool one can use to give the Optimizer accurate information.  I usually find this the best way to triage a bad plan as it is not a global change, it only effects a single execution of a statement in my session.  If luck has it that using a `CARDINALITY` hint yields an optimal plan, one can move on to debugging where the cardinality is being miscalculated.  Generally the bad cardinality is the result of non-representative table/column stats, but it also may be due to data correlation or other factors.  This is where it pays off to know and understand the size and shape of the data.  If the Optimizer still chooses a bad plan even with the correct cardinality estimates, it's time to place a call to Oracle Support as more in-depth debugging is likely required.

#### Where Cardinality Can Go Wrong

There are several common scenarios that can lead to inaccurate cardinality estimates.  Some of those on the list are:

- **Data skew**: _Is the NDV inaccurate due to data skew and a poor dbms_stats sample?_
- **Data correlation**: _Are two or more predicates related to each other?_
- **Out-of-range values**: _Is the predicate within the range of known values?_
- **Use of functions in predicates**: _Is the 5% cardinality guess for functions accurate?_
- **Stats gathering strategies**: _Is your stats gathering strategy yielding representative stats?_

Some possible solutions to these issues are:

- **Data skew**: _Choose a sample size that yields accurate NDV.  Use [`DBMS_STATS.AUTO_SAMPLE_SIZE` in 11g](http://structureddata.org/2007/09/17/oracle-11g-enhancements-to-dbms_stats/)._
- **Data correlation**: _Use [Extended Stats in 11g](http://structureddata.org/2007/10/31/oracle-11g-extended-statistics/).  If <= 10.2.0.3 use a `CARDINALITY` hint if possible._
- **Out-of-range values**: _Gather or manually set the statistics._
- **Use of functions in predicates**: _Use a `CARDINALITY` hint where possible._
- **Stats gathering strategies**: _Use `AUTO_SAMPLE_SIZE`.  Adjust only where necessary.  Be mindful of tables with skewed data._

### How To Best Work With Oracle Support

If you are unable to get to the root cause on your own, it is likely that you will be in contact with Oracle Support.  To best assist the support analyst I would recommend you gather the following in addition to the query text:

- Output from the `GATHER_PLAN_STATISTICS` and `DBMS_XPLAN.DISPLAY_CURSOR`
- `SQLTXPLAN` output.  See [Metalink Note 215187.1](https://metalink.oracle.com/metalink/plsql/ml2_documents.showDocument?p_database_id=NOT&p_id=215187.1)
- 10053 trace output.  See [Metalink Note 225598.1](https://metalink.oracle.com/metalink/plsql/ml2_documents.showDocument?p_database_id=NOT&p_id=225598.1)
- DDL for all objects used (and dependencies) in the query.  This is best gotten as a `expdp` (data pump) using `CONTENT=METADATA_ONLY`.  This will also include the object statistics.
- Output from: 
  `select pname, pval1 from sys.aux_stats$ where sname='SYSSTATS_MAIN';`
- A copy of your init.ora

Having this data ready before you even make the call (or create the SR on-line) should give you a jump on getting a quick(er) resolution.

### Summary

While this blog post is not meant to be a comprehensive troubleshooting guide for bad execution plans, I do hope that it does help point you in the right direction the next time you encounter one.  Many of the Optimizer issues I've seen are due to incorrect cardinality estimates, quite often due to inaccurate NDV or the result of data correlation.  I believe that if you use a systematic approach you will find that debugging bad execution plans may be as easy as just getting the cardinality estimate correct.
