---
author: Greg Rahn
comments: true
date: 2008-10-14T08:00:26.000Z
layout: post
slug: dbms_stats-method_opt-and-for-all-indexed-columns
title: 'DBMS_STATS, METHOD_OPT and FOR ALL INDEXED COLUMNS'
wp_id: 190
wp_categories:
  - 10gR2
  - 11gR1
  - Data Warehousing
  - Execution Plans
  - Optimizer
  - Oracle
  - Performance
  - SQL Tuning
  - Statistics
  - Troubleshooting
wp_tags:
  - cardinality
  - DBMS_STATS
  - Execution Plans
  - FOR ALL INDEXED COLUMNS
  - gather_table_stats
  - METHOD_OPT
  - Optimizer
  - selectivity
---

I've written before on [choosing an optimal stats gathering strategy](/2008/03/26/choosing-an-optimal-stats-gathering-strategy/) but I recently came across a scenario that I didn't directly blog about and think it deserves attention.  As I mentioned in that [previous post](/2008/03/26/choosing-an-optimal-stats-gathering-strategy/), one should only deviate from the defaults when they have a reason to, and fully understand that reason and the effect of that decision.

### Understanding METHOD_OPT

The `METHOD_OPT` parameter of `DBMS_STATS` controls two things:
1. on which columns statistics will be collected
1. on which columns histograms will be collected (and how many buckets)

It is **very** important to understand #1 and how the choice of `METHOD_OPT` effects the collection of column statistics.

### Prerequisite: Where Do I Find Column Statistics?

Understanding where to find column statistics is vital for [troubleshooting bad execution plans](/2007/11/21/troubleshooting-bad-execution-plans/).  These views will be the arrows in your quiver:

- USER_TAB_COL_STATISTICS
- USER_PART_COL_STATISTICS
- USER_SUBPART_COL_STATISTICS

Depending on if the table is partitioned or subpartitioned, and depending on what `GRANULARITY` the stats were gathered with, the latter two of those views may or may not be populated.

### The Bane of METHOD_OPT: FOR ALL INDEXED COLUMNS

If you are using `FOR ALL INDEXED COLUMNS` as part of your `METHOD_OPT` you probably **should not** be.  Allow me to explain.  Using `MENTOD_OPT=>'FOR ALL INDEXED COLUMNS SIZE AUTO'` (a common `METHOD_OPT` I see) tells `DBMS_STATS`: "_only gather stats on columns that participate in an index and based on data distribution and the workload of those indexed columns decide if a histogram should be created and how many buckets it should contain_".  Is that really what you want?  My guess is probably not.  Let me work through a few examples to explain why.

I'm going to start with this table. 

```
SQL> exec dbms_random.initialize(1);

PL/SQL procedure successfully completed.

SQL> create table t1
  2  as
  3  select
  4    column_value                    pk,
  5    round(dbms_random.value(1,2))   a,
  6    round(dbms_random.value(1,5))   b,
  7    round(dbms_random.value(1,10))  c,
  8    round(dbms_random.value(1,100)) d,
  9    round(dbms_random.value(1,100)) e
 10  from table(counter(1,1000000))
 11  /

Table created.

SQL> begin
  2    dbms_stats.gather_table_stats(
  3      ownname => user ,
  4      tabname => 'T1' ,
  5      estimate_percent => 100 ,
  6      cascade => true);
  7  end;
  8  /

PL/SQL procedure successfully completed.

SQL> select
  2    COLUMN_NAME, NUM_DISTINCT, HISTOGRAM, NUM_BUCKETS,
  3    to_char(LAST_ANALYZED,'yyyy-dd-mm hh24:mi:ss') LAST_ANALYZED
  4  from user_tab_col_statistics
  5  where table_name='T1'
  6  /

COLUMN_NAME NUM_DISTINCT HISTOGRAM       NUM_BUCKETS LAST_ANALYZED
----------- ------------ --------------- ----------- -------------------
PK               1000000 NONE                      1 2008-13-10 18:39:51
A                      2 NONE                      1 2008-13-10 18:39:51
B                      5 NONE                      1 2008-13-10 18:39:51
C                     10 NONE                      1 2008-13-10 18:39:51
D                    100 NONE                      1 2008-13-10 18:39:51
E                    100 NONE                      1 2008-13-10 18:39:51

6 rows selected.
```

This 6 column table contains 1,000,000 rows of randomly generated numbers.  I've queried USER_TAB_COL_STATISTICS to display some of the important attributes (NDV, Histogram, Number of  Buckets, etc).

I'm going to now put an index on T1(PK), delete the stats and recollect stats using two different `METHOD_OPT` parameters that each use `'FOR ALL INDEXED COLUMNS'`. 

```
SQL> create unique index PK_T1 on T1(PK);

Index created.

SQL> begin
  2    dbms_stats.delete_table_stats(user,'T1');
  3
  4    dbms_stats.gather_table_stats(
  5      ownname => user ,
  6      tabname => 'T1' ,
  7      estimate_percent => 100 ,
  8      method_opt => 'for all indexed columns' ,
  9      cascade => true);
 10  end;
 11  /

PL/SQL procedure successfully completed.

SQL> select COLUMN_NAME, NUM_DISTINCT, HISTOGRAM, NUM_BUCKETS,
  2  to_char(LAST_ANALYZED,'yyyy-dd-mm hh24:mi:ss') LAST_ANALYZED
  3  from user_tab_col_statistics
  4  where table_name='T1'
  5  /

COLUMN_NAME NUM_DISTINCT HISTOGRAM       NUM_BUCKETS LAST_ANALYZED
----------- ------------ --------------- ----------- -------------------
PK               1000000 HEIGHT BALANCED          75 2008-13-10 18:41:10

SQL> begin
  2    dbms_stats.delete_table_stats(user,'T1');
  3
  4    dbms_stats.gather_table_stats(
  5      ownname => user ,
  6      tabname => 'T1' ,
  7      estimate_percent => 100 ,
  8      method_opt => 'for all indexed columns size auto' ,
  9      cascade => true);
 10  end;
 11  /

PL/SQL procedure successfully completed.

SQL> select COLUMN_NAME, NUM_DISTINCT, HISTOGRAM, NUM_BUCKETS,
  2  to_char(LAST_ANALYZED,'yyyy-dd-mm hh24:mi:ss') LAST_ANALYZED
  3  from user_tab_col_statistics
  4  where table_name='T1'
  5  /

COLUMN_NAME NUM_DISTINCT HISTOGRAM       NUM_BUCKETS LAST_ANALYZED
----------- ------------ --------------- ----------- -------------------
PK               1000000 NONE                      1 2008-13-10 18:41:12

```

Notice that in both cases only column PK has stats on it.  Columns A,B,C,D and E do not have any stats collected on them.  Also note that when no `SIZE` clause is specified, it defaults to 75 buckets.

Now one might think that is no big deal or perhaps they do not realize this is happening because they do not look at their stats.  Let's see what we get for cardinality estimates from the Optimizer for a few scenarios.

```
SQL> select /*+ gather_plan_statistics */
  2    count(*)
  3  from t1
  4  where a=1
  5  /

  COUNT(*)
----------
    500227

SQL> select * from table(dbms_xplan.display_cursor(null, null, 'allstats last'));

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------
SQL_ID  4df0g0r99zmba, child number 0
-------------------------------------
select /*+ gather_plan_statistics */   count(*) from t1 where a=1

Plan hash value: 3724264953

-------------------------------------------------------------------------------------
| Id  | Operation          | Name | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
-------------------------------------------------------------------------------------
|   1 |  SORT AGGREGATE    |      |      1 |      1 |      1 |00:00:00.24 |    3466 |
|*  2 |   TABLE ACCESS FULL| T1   |      1 |  10000 |    500K|00:00:00.50 |    3466 |
-------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("A"=1)
```


Notice the E-Rows estimate for T1.  The Optimizer is estimating 10,000 rows when in reality there is 500,227.  The estimate is off by more than an order of magnitude (50x).  Normally the calculation for the cardinality would be (for a one table single equality predicate): number of rows in T1 * 1/NDV = 1,000,000 * 1/2 = 500,000 but in this case 10,000 is the estimate.  Strangely enough (or not), 10,000 is exactly 0.01 (1%) of 1,000,000.  Because there are no column stats for T1.A, the Optimizer is forced to make a guess, and that guess is 1%.

As you can see from the 10053 trace (below), since there are no statistics on the column, defaults are used.  In this case they yield very poor cardinality estimations.

```
SINGLE TABLE ACCESS PATH
  -----------------------------------------
  BEGIN Single Table Cardinality Estimation
  -----------------------------------------
  Column (#2): A(NUMBER)  NO STATISTICS (using defaults)
    AvgLen: 13.00 NDV: 31250 Nulls: 0 Density: 3.2000e-05
  Table: T1  Alias: T1
    Card: Original: 1000000  Rounded: 10000  Computed: 10000.00  Non Adjusted: 10000.00
  -----------------------------------------
  END   Single Table Cardinality Estimation
  -----------------------------------------
```

Now that I've demonstrated how poor the cardinality estimation was with a single equality predicate, let's see what two equality predicates gives us for a cardinality estimate.

```
SQL> select /*+ gather_plan_statistics */
  2    count(*)
  3  from t1
  4  where a=1
  5    and b=3
  6  /

  COUNT(*)
----------
    124724

SQL> select * from table(dbms_xplan.display_cursor(null, null, 'allstats last'));

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------
SQL_ID  ctq8q59qdymw6, child number 0
-------------------------------------
select /*+ gather_plan_statistics */   count(*) from t1 where a=1   and b=3

Plan hash value: 3724264953

-------------------------------------------------------------------------------------
| Id  | Operation          | Name | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
-------------------------------------------------------------------------------------
|   1 |  SORT AGGREGATE    |      |      1 |      1 |      1 |00:00:00.19 |    3466 |
|*  2 |   TABLE ACCESS FULL| T1   |      1 |    100 |    124K|00:00:00.25 |    3466 |
-------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(("A"=1 AND "B"=3))

```

Yikes.  In this case the cardinality estimate is 100 when the actual number of rows is 124,724, a difference of over 3 orders of magnitude (over 1000x). Where did the 100 row estimate come from?  In this case there are two equality predicates so the selectivity is calculated as 1% * 1% or 0.01 * 0.01 = 0.0001. 1,000,000 * 0.0001 = 100.  Funny that. (The 1% is the default selectivity for an equality predicate w/o stats.)

Now let's add a derived predicate as well and check the estimates. 

```
SQL> select /*+ gather_plan_statistics */
  2    count(*)
  3  from t1
  4  where a=1
  5    and b=3
  6    and d+e > 50
  7  /

  COUNT(*)
----------
    109816

SQL> select * from table(dbms_xplan.display_cursor(null, null, 'allstats last'));

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------
SQL_ID  5x200q9rqvvfu, child number 0
-------------------------------------
select /*+ gather_plan_statistics */   count(*) from t1 where a=1   and b=3
 and d+e > 50

Plan hash value: 3724264953

-------------------------------------------------------------------------------------
| Id  | Operation          | Name | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
-------------------------------------------------------------------------------------
|   1 |  SORT AGGREGATE    |      |      1 |      1 |      1 |00:00:00.22 |    3466 |
|*  2 |   TABLE ACCESS FULL| T1   |      1 |      5 |    109K|00:00:00.33 |    3466 |
-------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(("A"=1 AND "B"=3 AND "D"+"E">50))
```

Doh!  The cardinality estimate is now 5, but the actual number of rows being returned is 109,816.   Not good at all.  The Optimizer estimated 5 rows because it used a default selectivity of 1% (for A=1) * 1% (for B=3) * 5% (for D+E > 50) * 1,000,000 rows.    Now can you see why column statistics are very important?  All it takes is a few predicates and the cardinality  estimation becomes very small, very fast.  Now consider this:

- What is likely to happen in a data warehouse where the queries are 5+ table joins and the fact table columns do not have indexes?
- Would the Optimizer choose the correct driving table?
- Would nested loops plans probably be chosen when it is really not appropriate?

Hopefully you can see where this is going.  If you don't, here is the all too common chain of events:

- Non representative (or missing) statistics lead to
- Poor cardinality estimates which leads to
- Poor access path selection which leads to
- Poor join method selection which leads to
- Poor join order selection which leads to
- Poor SQL execution times

#### Take 2: Using the Defaults

Now I'm going to recollect stats with a default `METHOD_OPT` and run through the 3 execution plans again: 

```
SQL> begin
  2    dbms_stats.delete_table_stats(user,'t1');
  3
  4    dbms_stats.gather_table_stats(
  5      ownname => user ,
  6      tabname => 'T1' ,
  7      estimate_percent => 100 ,
  8      degree => 8,
  9      cascade => true);
 10  end;
 11  /

PL/SQL procedure successfully completed.

SQL> select column_name, num_distinct, histogram, NUM_BUCKETS,
  2  to_char(LAST_ANALYZED,'yyyy-dd-mm hh24:mi:ss') LAST_ANALYZED
  3  from user_tab_col_statistics where table_name='T1'
  4  /

COLUMN_NAME NUM_DISTINCT HISTOGRAM       NUM_BUCKETS LAST_ANALYZED
----------- ------------ --------------- ----------- -------------------
PK               1000000 NONE                      1 2008-13-10 19:44:32
A                      2 FREQUENCY                 2 2008-13-10 19:44:32
B                      5 FREQUENCY                 5 2008-13-10 19:44:32
C                     10 FREQUENCY                10 2008-13-10 19:44:32
D                    100 NONE                      1 2008-13-10 19:44:32
E                    100 NONE                      1 2008-13-10 19:44:32

6 rows selected.
```

```
SQL> select /*+ gather_plan_statistics */
  2    count(*)
  3  from t1
  4  where a=1
  5  /

  COUNT(*)
----------
    500227

SQL> select * from table(dbms_xplan.display_cursor(null, null, 'allstats last'));

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------
SQL_ID  4df0g0r99zmba, child number 0
-------------------------------------
select /*+ gather_plan_statistics */   count(*) from t1 where a=1

Plan hash value: 3724264953

-------------------------------------------------------------------------------------
| Id  | Operation          | Name | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
-------------------------------------------------------------------------------------
|   1 |  SORT AGGREGATE    |      |      1 |      1 |      1 |00:00:00.20 |    3466 |
|*  2 |   TABLE ACCESS FULL| T1   |      1 |    500K|    500K|00:00:00.50 |    3466 |
-------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("A"=1)
```

```
SQL> select /*+ gather_plan_statistics */
  2    count(*)
  3  from t1
  4  where a=1
  5    and b=3
  6  /

  COUNT(*)
----------
    124724

SQL> select * from table(dbms_xplan.display_cursor(null, null, 'allstats last'));

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------
SQL_ID  ctq8q59qdymw6, child number 0
-------------------------------------
select /*+ gather_plan_statistics */   count(*) from t1 where a=1   and b=3

Plan hash value: 3724264953

-------------------------------------------------------------------------------------
| Id  | Operation          | Name | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
-------------------------------------------------------------------------------------
|   1 |  SORT AGGREGATE    |      |      1 |      1 |      1 |00:00:00.14 |    3466 |
|*  2 |   TABLE ACCESS FULL| T1   |      1 |    124K|    124K|00:00:00.25 |    3466 |
-------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(("B"=3 AND "A"=1))
```

```
SQL> select /*+ gather_plan_statistics */
  2    count(*)
  3  from t1
  4  where a=1
  5    and b=3
  6    and d+e > 50
  7  /

  COUNT(*)
----------
    109816

SQL> select * from table(dbms_xplan.display_cursor(null, null, 'allstats last'));

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------
SQL_ID  5x200q9rqvvfu, child number 0
-------------------------------------
select /*+ gather_plan_statistics */   count(*) from t1 where a=1   and b=3
 and d+e>50

Plan hash value: 3724264953

-------------------------------------------------------------------------------------
| Id  | Operation          | Name | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
-------------------------------------------------------------------------------------
|   1 |  SORT AGGREGATE    |      |      1 |      1 |      1 |00:00:00.17 |    3466 |
|*  2 |   TABLE ACCESS FULL| T1   |      1 |   6236 |    109K|00:00:00.22 |    3466 |
-------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(("B"=3 AND "A"=1 AND "D"+"E">50))
```

As you can see, the first two queries have spot on cardinality estimates, but the the third query isn't as good as it uses a column combination and there are no stats on D+E columns, only D and E individually.  I'm going to rerun the third query with dynamic sampling set to 4 (in 10g it defaults to 2) and reevaluate the cardinality estimate.

```
SQL> alter session set optimizer_dynamic_sampling=4;

Session altered.

SQL> select /*+ gather_plan_statistics */
  2    count(*)
  3  from t1
  4  where a=1
  5    and b=3
  6    and d+e > 50
  7  /

  COUNT(*)
----------
    109816

SQL> select * from table(dbms_xplan.display_cursor(null, null, 'allstats last'));

PLAN_TABLE_OUTPUT
------------------------------------------------------------------------------------------
SQL_ID  5x200q9rqvvfu, child number 1
-------------------------------------
select /*+ gather_plan_statistics */   count(*) from t1 where a=1   and b=3
 and d+e > 50

Plan hash value: 3724264953

-------------------------------------------------------------------------------------
| Id  | Operation          | Name | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
-------------------------------------------------------------------------------------
|   1 |  SORT AGGREGATE    |      |      1 |      1 |      1 |00:00:00.17 |    3466 |
|*  2 |   TABLE ACCESS FULL| T1   |      1 |    102K|    109K|00:00:00.22 |    3466 |
-------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(("B"=3 AND "A"=1 AND "D"+"E">50))

Note
-----
   - dynamic sampling used for this statement
```

Bingo!  Close enough to call statistically equivalent.

### Summary

I hope this little exercise demonstrates how important it is to have representative statistics and that when statistics are representative the Optimizer can very often accurately estimate the cardinality and thus choose the best plan for the query.  Remember these points:

- Recent statistics do not necessarily equate to representative statistics.
- Statistics are required on all columns to yield good plans - not just indexed columns.
- You probably should not be using `METHOD_OPT => 'FOR ALL INDEXED COLUMNS SIZE AUTO'`, especially in a data warehouse where indexes are used sparingly.
- Dynamic Sampling can assist with cardinality estimates where existing stats are not enough.

_Tests performed on 10.2.0.4_
