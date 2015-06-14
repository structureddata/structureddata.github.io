---
author: Greg Rahn
comments: true
date: 2011-06-08
layout: post
slug: implicit-datatype-conversion-histograms-bad-execution-plan
title: Implicit Datatype Conversion + Histograms = Bad Execution Plan?
wp_id: 1366
wp_categories:
  - Optimizer
  - Oracle
wp_tags:
  - cardinality
  - histograms
  - Optimizer
  - selectivity
---

Earlier today I exchanged some tweets with [@martinberx](http://twitter.com/martinberx) about some optimizer questions and after [posting more information on the ORACLE-L list](http://www.freelists.org/post/oracle-l/missing-link-in-my-10053-trace), I was able to reproduce what he was observing.

### The issue:

> DB: 11.2.0.2.0 - 64bit
> I have a small query with a little error, which causes big troubles.
> The relevant part of the query is
> WHERE ....
> AND inst_prod_type=003
> AND setid='COM01'
> 
> but INST_PROD_TYPE is VARCHAR2.
> 
> this leads to filter[ (TO_NUMBER("INST_PROD_TYPE")=3 AND "SETID"='COM01') ]
> 
> based on this TO_NUMBER ( I guess!) the optimiser takes a fix selectivity of 1%.
> 
> Can someone tell me if this 1% is right? Jonathan Lewis "CBO Fundamentals" on page 133 is only talking about character expressions.
> 
> Unfortunately there are only 2 distinct values of INST_PROD_TYPE so this artificial [low] selectivity leads to my problem:
> An INDEX SKIP SCAN on PS0RF_INST_PROD is choosen. (columns of PS0RF_INST_PROD: INST_PROD_TYPE, SETID, INST_PROD_ID )
> 
> After fixing the statement to
> AND inst_prod_type='003'
> another index is used and the statement performs as expected.
> 
> Now I have no problem, but want to find the optimizers decisions in my 10053 traces.

### The Important Bits of Information

From Martin's email we need to pay close attention to:

- Predicate of "inst_prod_type=003" where INST_PROD_TYPE is VARCHAR2 (noting no single quotes around 003)
- Implicite datatype conversion in predicate section of explain plan - TO_NUMBER("INST_PROD_TYPE")=3
- only 2 distinct values of INST_PROD_TYPE

From this information I'll construct the following test case: 

```
create table foo (c1 varchar2(8));
insert into foo select '003' from dual connect by level <= 1000000;
insert into foo select '100' from dual connect by level <= 1000000;
commit;
exec dbms_stats.gather_table_stats(user,'foo');

```

And using the [display_raw function](/2007/10/16/how-to-display-high_valuelow_value-columns-from-user_tab_col_statistics/) we'll look at the column stats. 

```
col low_val     for a8
col high_val    for a8
col data_type   for a9
col column_name for a11

select
   a.column_name,
   display_raw(a.low_value,b.data_type) as low_val,
   display_raw(a.high_value,b.data_type) as high_val,
   b.data_type,
   a.density,
   a.histogram,
   a.num_buckets
from
   user_tab_col_statistics a, user_tab_cols b
where
   a.table_name='FOO' and
   a.table_name=b.table_name and
   a.column_name=b.column_name
/

COLUMN_NAME LOW_VAL  HIGH_VAL DATA_TYPE    DENSITY HISTOGRAM       NUM_BUCKETS
----------- -------- -------- --------- ---------- --------------- -----------
C1          003      100      VARCHAR2          .5 NONE                      1

```

Take note of the lack of a histogram.

Now let's see what the CBO estimates for a simple query with and without quotes (explicit cast and implicit cast).

```
SQL> explain plan for select count(*) from foo where c1=003;

Explained.

SQL> select * from table(dbms_xplan.display());

PLAN_TABLE_OUTPUT
---------------------------------------------------------------------------
Plan hash value: 1342139204

---------------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |     1 |     4 |   875   (3)| 00:00:11 |
|   1 |  SORT AGGREGATE    |      |     1 |     4 |            |          |
|*  2 |   TABLE ACCESS FULL| FOO  |  1000K|  3906K|   875   (3)| 00:00:11 |
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(TO_NUMBER("C1")=003)

14 rows selected.

SQL> explain plan for select count(*) from foo where c1='003';

Explained.

SQL> select * from table(dbms_xplan.display());

PLAN_TABLE_OUTPUT
---------------------------------------------------------------------------
Plan hash value: 1342139204

---------------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |     1 |     4 |   868   (2)| 00:00:11 |
|   1 |  SORT AGGREGATE    |      |     1 |     4 |            |          |
|*  2 |   TABLE ACCESS FULL| FOO  |  1000K|  3906K|   868   (2)| 00:00:11 |
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("C1"='003')

14 rows selected.
```

In this case the estimated number of rows is spot on - 1 million rows.  Now lets regather stats and because of our queries using C1 predicates, it will become a candidate for a histogram.  We can see this from sys.col_usage$.

```
select  oo.name owner,
        o.name table_name,
        c.name column_name,
        u.equality_preds,
        u.equijoin_preds,
        u.nonequijoin_preds,
        u.range_preds,
        u.like_preds,
        u.null_preds,
        u.timestamp
from    sys.col_usage$ u,
        sys.obj$ o,
        sys.user$ oo,
        sys.col$ c
where   o.obj#   = u.obj#
and     oo.user# = o.owner#
and     c.obj#   = u.obj#
and     c.col#   = u.intcol#
and     oo.name  = 'GRAHN'
and     o.name   = 'FOO'
/

OWNER TABLE_NAME COLUMN_NAME EQUALITY_PREDS EQUIJOIN_PREDS NONEQUIJOIN_PREDS RANGE_PREDS LIKE_PREDS NULL_PREDS TIMESTAMP
----- ---------- ----------- -------------- -------------- ----------------- ----------- ---------- ---------- -------------------
GRAHN FOO        C1                       1              0                 0           0          0          0 2011-06-08 22:29:59
```

Regather stats and re-check the column stats:

```
SQL> exec dbms_stats.gather_table_stats(user,'foo');

PL/SQL procedure successfully completed.

SQL> select
  2     a.column_name,
  3     display_raw(a.low_value,b.data_type) as low_val,
  4     display_raw(a.high_value,b.data_type) as high_val,
  5     b.data_type,
  6     a.density,
  7     a.histogram,
  8     a.num_buckets
  9  from
 10     user_tab_col_statistics a, user_tab_cols b
 11  where
 12     a.table_name='FOO' and
 13     a.table_name=b.table_name and
 14     a.column_name=b.column_name
 15  /

COLUMN_NAME LOW_VAL  HIGH_VAL DATA_TYPE    DENSITY HISTOGRAM       NUM_BUCKETS
----------- -------- -------- --------- ---------- --------------- -----------
C1          003      100      VARCHAR2  2.5192E-07 FREQUENCY                 2
```

Note the presence of a frequency histogram.  Now let's re-explain: 

```
SQL> explain plan for select count(*) from foo where c1=003;

Explained.

SQL> select * from table(dbms_xplan.display());

PLAN_TABLE_OUTPUT
---------------------------------------------------------------------------
Plan hash value: 1342139204

---------------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |     1 |     4 |   875   (3)| 00:00:11 |
|   1 |  SORT AGGREGATE    |      |     1 |     4 |            |          |
|*  2 |   TABLE ACCESS FULL| FOO  |     1 |     4 |   875   (3)| 00:00:11 |
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(TO_NUMBER("C1")=003)

SQL> explain plan for select count(*) from foo where c1='003';

Explained.

SQL> select * from table(dbms_xplan.display());

PLAN_TABLE_OUTPUT
---------------------------------------------------------------------------
Plan hash value: 1342139204

---------------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |     1 |     4 |   868   (2)| 00:00:11 |
|   1 |  SORT AGGREGATE    |      |     1 |     4 |            |          |
|*  2 |   TABLE ACCESS FULL| FOO  |  1025K|  4006K|   868   (2)| 00:00:11 |
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("C1"='003')
```

And whammy!  Note that the implicit cast [ `filter(TO_NUMBER("C1")=003)` ] now has an estimate of 1 row (when we know there is 1 million).

So what is going on here?  Let's dig into the optimizer trace for some insight:

```
SINGLE TABLE ACCESS PATH
  Single Table Cardinality Estimation for FOO[FOO]
  Column (#1):
    NewDensity:0.243587, OldDensity:0.000000 BktCnt:5458, PopBktCnt:5458, PopValCnt:2, NDV:2
  Column (#1): C1(
    AvgLen: 4 NDV: 2 Nulls: 0 Density: 0.243587
    Histogram: Freq  #Bkts: 2  UncompBkts: 5458  EndPtVals: 2
  Using prorated density: 0.000000 of col #1 as selectvity of out-of-range/non-existent value pred
  Table: FOO  Alias: FOO
    Card: Original: 2000000.000000  Rounded: 1  Computed: 0.50  Non Adjusted: 0.50
  Access Path: TableScan
    Cost:  875.41  Resp: 875.41  Degree: 0
      Cost_io: 853.00  Cost_cpu: 622375564
      Resp_io: 853.00  Resp_cpu: 622375564
  Best:: AccessPath: TableScan
         Cost: 875.41  Degree: 1  Resp: 875.41  Card: 0.50  Bytes: 0
```

As you can see from the line 

```
Using prorated density: 0.000000 of col #1 as selectvity of out-of-range/non-existent value pred
```

The presence of the histogram and the implicit conversion of `TO_NUMBER("C1")=003` causes the CBO to use a density of 0 because it thinks it's a non-existent value. The reason for this is that `TO_NUMBER("C1")=003` is the same as `TO_NUMBER("C1")=3` and for the histogram the CBO uses `TO_CHAR(C1)='3'` and 3 is not present in the histogram only `'003'` and `'100'`.

### Dumb Luck?

So, what if the predicate contained a number that was not left padded with zeros, say 100, the other value we put in the table?

```
SQL> explain plan for select count(*) from foo where c1=100;

Explained.

SQL> select * from table(dbms_xplan.display());

PLAN_TABLE_OUTPUT
---------------------------------------------------------------------------
Plan hash value: 1342139204

---------------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |     1 |     4 |   875   (3)| 00:00:11 |
|   1 |  SORT AGGREGATE    |      |     1 |     4 |            |          |
|*  2 |   TABLE ACCESS FULL| FOO  |  1009K|  3944K|   875   (3)| 00:00:11 |
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(TO_NUMBER("C1")=100)
```

While not exact, the CBO estimate is quite close to the 1 million rows with C1='100'.  

### Summary

It's quite clear that Martin's issue came down to the following:

- implicit casting
- presences of histogram
- zero left padded number/string

The combination of these created a scenario where the CBO thinks the value is out-of-range and uses a prorated density of 0 resulting in a cardinality of 1 when there are many more rows than 1.

The moral of the story here is always cast your predicates correctly.  This includes explicit cast of date types as well - never rely on the nls settings.

All tests performed on 11.2.0.2.
