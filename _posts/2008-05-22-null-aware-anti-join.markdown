---
author: Greg Rahn
comments: true
date: 2008-05-22T08:00:46.000Z
layout: post
slug: null-aware-anti-join
title: Null-Aware Anti-Join
wp_id: 64
wp_categories:
  - 10gR2
  - 11gR1
  - Data Warehousing
  - Execution Plans
  - Optimizer
  - Oracle
  - Performance
wp_tags:
  - execution plan
  - filter
  - lnnvl
  - null-aware anti-join
---

Recently someone showed me a query execution plan with an operation of `HASH JOIN ANTI NA`.  At first, it was thought maybe it was a bug and the operation had a type-o in it, but after further research it was discovered it was a valid operation and a new cost-based query transformation for subquery unnesting in [Oracle Database 11g](http://www.oracle.com/technology/products/database/oracle11g/index.html).  The **NA** stands for Null-Aware.  There is also a second type of **Null-Aware Anti-Join**, which is the **Single Null-Aware Anti-Join** which is displayed in the execution plan as `ANTI SNA`.  The null-aware anti-join may be computed using each of the three types of of join operations: the sort-merge join, hash join and nested loops join.

What is the advantage of a Null-Aware Anti-Join?  If we look at the [patent application for Null-Aware Anti-Joins](http://www.google.com/patents?id=4bqBAAAAEBAJ&dq=null+aware+anti-join) we will see that paragraph 0006 gives a brief description:

> [0006]  A common type of query that is optimized is a query that contains a subquery whose join condition involves the NOT IN/ALL operator (NOT IN is equivalent to != ALL).  In data-warehouses with reporting applications, such queries and subqueries are usually evaluated on very large sets of data.  Thus, it is critical to make such queries scale in any SQL execution engine.  When such queries are not optimized using anti-join, the subquery is executing an operation that is effectively a Cartesian product, which is quite inefficient.

Before we look at the performance side of things, lets just take a look at some simple examples with our favorite EMP table.

```
SQL> select * from emp;

     EMPNO ENAME      JOB              MGR HIREDATE          SAL       COMM     DEPTNO
---------- ---------- --------- ---------- ---------- ---------- ---------- ----------
      7369 SMITH      CLERK           7902 1980-12-17        800                    20
      7499 ALLEN      SALESMAN        7698 1981-02-20       1600        300         30
      7521 WARD       SALESMAN        7698 1981-02-22       1250        500         30
      7566 JONES      MANAGER         7839 1981-04-02       2975                    20
      7654 MARTIN     SALESMAN        7698 1981-09-28       1250       1400         30
      7698 BLAKE      MANAGER         7839 1981-05-01       2850                    30
      7782 CLARK      MANAGER         7839 1981-06-09       2450                    10
      7788 SCOTT      ANALYST         7566 1987-04-19       3000                    20
      7839 KING       PRESIDENT            1981-11-17       5000                    10
      7844 TURNER     SALESMAN        7698 1981-09-08       1500          0         30
      7876 ADAMS      CLERK           7788 1987-05-23       1100                    20
      7900 JAMES      CLERK           7698 1981-12-03        950                    30
      7902 FORD       ANALYST         7566 1981-12-03       3000                    20
      7934 MILLER     CLERK           7782 1982-01-23       1300                    10
```

As you can see, there is one row where MGR is null.

In the below examples, I'm going to refer to the outer query as the _left side_, and the subquery as the _right side_.  Each test case has the query, the execution plan and a snippet of the 10053 trace.

### 11.1.0.6

#### Test Case 1: Either Side Can Be Null

```
select count(*)
from   emp
where  mgr not in (select mgr from emp);

Execution Plan
----------------------------------------------------------
Plan hash value: 54517352

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     1 |     8 |     5  (20)| 00:00:01 |
|   1 |  SORT AGGREGATE     |      |     1 |     8 |            |          |
|*  2 |   HASH JOIN ANTI NA |      |    13 |   104 |     5  (20)| 00:00:01 |
|   3 |    TABLE ACCESS FULL| EMP  |    14 |    56 |     2   (0)| 00:00:01 |
|   4 |    TABLE ACCESS FULL| EMP  |    14 |    56 |     2   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("MGR"="MGR")
```
<pre>
*****************************
Cost-Based Subquery Unnesting
*****************************
SU: Unnesting query blocks in query block SEL$1 (#1) that are valid to unnest.
Subquery Unnesting on query block SEL$1 (#1)
SU: Performing unnesting that does not require costing.
SU: Considering subquery unnest on query block SEL$1 (#1).
SU:   Checking validity of unnesting subquery SEL$2 (#2)
SU:   Passed validity checks.
SU:   <font color='red'>Transform ALL subquery to a null-aware antijoin.</font>
Registered qb: SEL$5DA710D3 0x77a2e6bc (SUBQUERY UNNEST SEL$1; SEL$2)
</pre>

#### Test Case 2: Right Side Is Not Null


```
select count(*)
from   emp
where  mgr not in (select mgr from emp where mgr is not null);

Execution Plan
----------------------------------------------------------
Plan hash value: 2818854569

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     1 |     8 |     5  (20)| 00:00:01 |
|   1 |  SORT AGGREGATE     |      |     1 |     8 |            |          |
|*  2 |   HASH JOIN ANTI SNA|      |    13 |   104 |     5  (20)| 00:00:01 |
|   3 |    TABLE ACCESS FULL| EMP  |    14 |    56 |     2   (0)| 00:00:01 |
|*  4 |    TABLE ACCESS FULL| EMP  |    13 |    52 |     2   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("MGR"="MGR")
   4 - filter("MGR" IS NOT NULL)
```

<pre>
*****************************
Cost-Based Subquery Unnesting
*****************************
SU: Unnesting query blocks in query block SEL$1 (#1) that are valid to unnest.
Subquery Unnesting on query block SEL$1 (#1)
SU: Performing unnesting that does not require costing.
SU: Considering subquery unnest on query block SEL$1 (#1).
SU:   Checking validity of unnesting subquery SEL$2 (#2)
SU:   Passed validity checks.
SU: <font color="red">Transform ALL subquery to a single null-aware antijoin.</font>
Registered qb: SEL$5DA710D3 0x67e897e8 (SUBQUERY UNNEST SEL$1; SEL$2)
</pre>

#### Test Case 3: Left Side Is Not Null

```
select count(*)
from   emp
where  mgr not in (select mgr from emp) and
       mgr is not null;

Execution Plan
----------------------------------------------------------
Plan hash value: 54517352

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     1 |     8 |     5  (20)| 00:00:01 |
|   1 |  SORT AGGREGATE     |      |     1 |     8 |            |          |
|*  2 |   HASH JOIN ANTI NA |      |    12 |    96 |     5  (20)| 00:00:01 |
|*  3 |    TABLE ACCESS FULL| EMP  |    13 |    52 |     2   (0)| 00:00:01 |
|   4 |    TABLE ACCESS FULL| EMP  |    14 |    56 |     2   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("MGR"="MGR")
   3 - filter("MGR" IS NOT NULL)
```

<pre>
*****************************
Cost-Based Subquery Unnesting
*****************************
SU: Unnesting query blocks in query block SEL$1 (#1) that are valid to unnest.
Subquery Unnesting on query block SEL$1 (#1)
SU: Performing unnesting that does not require costing.
SU: Considering subquery unnest on query block SEL$1 (#1).
SU:   Checking validity of unnesting subquery SEL$2 (#2)
SU:   Passed validity checks.
SU:   <font color="red">Transform ALL subquery to a null-aware antijoin.</font>
SU:   Checking validity of unnesting subquery SEL$2 (#3)
SU:   Validity checks failed.
Registered qb: SEL$5DA710D3 0x7a357c98 (SUBQUERY UNNEST SEL$1; SEL$2)
</pre>

#### Test Case 4: Neither Side Is Null

```
select count(*)
from   emp
where  mgr not in (select mgr from emp where mgr is not null) and
       mgr is not null;

Execution Plan
----------------------------------------------------------
Plan hash value: 868928733

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     1 |     8 |     5  (20)| 00:00:01 |
|   1 |  SORT AGGREGATE     |      |     1 |     8 |            |          |
|*  2 |   HASH JOIN ANTI    |      |    12 |    96 |     5  (20)| 00:00:01 |
|*  3 |    TABLE ACCESS FULL| EMP  |    13 |    52 |     2   (0)| 00:00:01 |
|*  4 |    TABLE ACCESS FULL| EMP  |    13 |    52 |     2   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("MGR"="MGR")
   3 - filter("MGR" IS NOT NULL)
   4 - filter("MGR" IS NOT NULL)
```
<pre>
*****************************
Cost-Based Subquery Unnesting
*****************************
SU: Unnesting query blocks in query block SEL$1 (#1) that are valid to unnest.
Subquery Unnesting on query block SEL$1 (#1)
SU: Performing unnesting that does not require costing.
SU: Considering subquery unnest on query block SEL$1 (#1).
SU:   Checking validity of unnesting subquery SEL$2 (#2)
SU:   Passed validity checks.
SU:   <font color="red">Transform ALL subquery to a regular antijoin.</font>
Registered qb: SEL$5DA710D3 0x73a4d370 (SUBQUERY UNNEST SEL$1; SEL$2)
</pre>

As you can see in Test Case 1 and Test Case 3, the optimizer chooses a **Null-Aware Anti-Join**.  In Test Case 2, a **Single Null-Aware Anti-Join** is chosen, and in Test Case 4 a **Regular Anti-Join** is chosen.

Let's compare the plans to 10.2.0.4. I used `optimizer_features_enable='10.2.0.4'` on my 11.1.0.6 database as well as tested it on 10.2.0.4; the plans are identical in both cases.

### 10.2.0.4

#### Test Case 1: Either Side Can Be Null

```
select count(*)
from   emp
where  mgr not in (select mgr from emp);

Execution Plan
----------------------------------------------------------
Plan hash value: 1842922539

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     1 |     4 |    14   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE     |      |     1 |     4 |            |          |
|*  2 |   FILTER            |      |       |       |            |          |
|   3 |    TABLE ACCESS FULL| EMP  |    14 |    56 |     2   (0)| 00:00:01 |
|*  4 |    TABLE ACCESS FULL| EMP  |     2 |     8 |     2   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter( NOT EXISTS (SELECT 0 FROM "EMP" "EMP" WHERE
              LNNVL("MGR":B1)))
   4 - filter(LNNVL("MGR":B1))
```

#### Test Case 2: Right Side Is Not Null

```
select count(*)
from   emp
where  mgr not in (select mgr from emp where mgr is not null);

Execution Plan
----------------------------------------------------------
Plan hash value: 1842922539

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     1 |     4 |    14   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE     |      |     1 |     4 |            |          |
|*  2 |   FILTER            |      |       |       |            |          |
|   3 |    TABLE ACCESS FULL| EMP  |    14 |    56 |     2   (0)| 00:00:01 |
|*  4 |    TABLE ACCESS FULL| EMP  |     2 |     8 |     2   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter( NOT EXISTS (SELECT 0 FROM "EMP" "EMP" WHERE "MGR" IS NOT
              NULL AND LNNVL("MGR":B1)))
   4 - filter("MGR" IS NOT NULL AND LNNVL("MGR":B1))
```

#### Test Case 3: Left Side Is Not Null

```
select count(*)
from   emp
where  mgr not in (select mgr from emp) and
       mgr is not null;

Execution Plan
----------------------------------------------------------
Plan hash value: 1842922539

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     1 |     4 |    14   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE     |      |     1 |     4 |            |          |
|*  2 |   FILTER            |      |       |       |            |          |
|*  3 |    TABLE ACCESS FULL| EMP  |    13 |    52 |     2   (0)| 00:00:01 |
|*  4 |    TABLE ACCESS FULL| EMP  |     2 |     8 |     2   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter( NOT EXISTS (SELECT 0 FROM "EMP" "EMP" WHERE
              LNNVL("MGR":B1)))
   3 - filter("MGR" IS NOT NULL)
   4 - filter(LNNVL("MGR":B1))
```

#### Test Case 4: Neither Side Is Null

```
select count(*)
from   emp
where  mgr not in (select mgr from emp where mgr is not null) and
       mgr is not null;

Execution Plan
----------------------------------------------------------
Plan hash value: 868928733

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     1 |     8 |     5  (20)| 00:00:01 |
|   1 |  SORT AGGREGATE     |      |     1 |     8 |            |          |
|*  2 |   HASH JOIN ANTI    |      |     1 |     8 |     5  (20)| 00:00:01 |
|*  3 |    TABLE ACCESS FULL| EMP  |    13 |    52 |     2   (0)| 00:00:01 |
|*  4 |    TABLE ACCESS FULL| EMP  |    13 |    52 |     2   (0)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("MGR"="MGR")
   3 - filter("MGR" IS NOT NULL)
   4 - filter("MGR" IS NOT NULL)
```

In 10.2.0.4 each of Test Case 1-3 have the same execution plan, but a different one than in 11.1.0.6 because of the new query transformation.  Test Case 4 has the same plan in both 10.2.0.4 and 11.1.0.6, which is expected, because neither side can be null and the new query transformation does not kick in.  Note the difference on line 2: The 11g plans use the null-aware anti-join, and the 10g plans use a filter.

### Performance Test

For a performance test case, I'm going to create two tables of 100,000 rows using the below script and run the Test Cases against them setting OFE to 11.1.0.6 and 10.2.0.4: 

```
drop table t1;

create table t1
as
select case when mod((rownum + 90000),1000) = 0
            then null
            else rownum
       end as a
from dual
connect by level >= 100000;

exec dbms_stats.gather_table_stats(user,'t1');

drop table t2;

create table t2
as
select case when mod((rownum + 90000),1000) = 0
            then null
            else rownum + 90000
       end as a
from dual
connect by level >= 100000;

exec dbms_stats.gather_table_stats(user,'t2');

```

#### Performance Test Results

Test Case	| 10.2.0.4 | 11.1.0.6
--- | --- | ---
1 | 00:00:08.24 | 00:00:00.05
2 | 00:12:31.24 | 00:00:00.10
3 | 00:00:09.08 | 00:00:00.05
4 | 00:00:00.10 | 00:00:00.10

Test Case 1 and 3 have around 82x better time with the 11.1.0.6 plan compared to 10.2.0.4, but the significant difference is with Test Case 2.  It's time was reduced by 7500x or so; from over 12 minutes to less than 1 second.  If we examine the 10.2.0.4 plans, we see the optimizer applies a filter push-down transformation using `NOT EXISTS` and `LNNVL`.

Let's examine the statistics of each execution from autotrace.

#### 10.2.0.4 Plan

```
Execution Plan
----------------------------------------------------------
Plan hash value: 59119136

----------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     1 |     4 |  4014K  (5)| 13:22:56 |
|   1 |  SORT AGGREGATE     |      |     1 |     4 |            |          |
|*  2 |   FILTER            |      |       |       |            |          |
|   3 |    TABLE ACCESS FULL| T1   |   100K|   390K|    45   (5)| 00:00:01 |
|*  4 |    TABLE ACCESS FULL| T2   |     1 |     4 |    45   (5)| 00:00:01 |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter( NOT EXISTS (SELECT 0 FROM "T2" "T2" WHERE "T2"."A" IS
              NOT NULL AND LNNVL("T2"."A":B1)))
   4 - filter("T2"."A" IS NOT NULL AND LNNVL("T2"."A":B1))


Statistics
----------------------------------------------------------
          1  recursive calls
          0  db block gets
   14137436  consistent gets
          0  physical reads
          0  redo size
        420  bytes sent via SQL*Net to client
        415  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
          1  rows processed
```

#### 11.1.0.6 Plan

```
Execution Plan
----------------------------------------------------------
Plan hash value: 1028670007

------------------------------------------------------------------------------------
| Id  | Operation           | Name | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     |
------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |      |     1 |     8 |       |   245   (3)| 00:00:03 |
|   1 |  SORT AGGREGATE     |      |     1 |     8 |       |            |          |
|*  2 |   HASH JOIN ANTI SNA|      |  9998 | 79984 |  1568K|   245   (3)| 00:00:03 |
|   3 |    TABLE ACCESS FULL| T1   |   100K|   390K|       |    44   (3)| 00:00:01 |
|*  4 |    TABLE ACCESS FULL| T2   | 99900 |   390K|       |    45   (5)| 00:00:01 |
------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("T1"."A"="T2"."A")
   4 - filter("T2"."A" IS NOT NULL)


Statistics
----------------------------------------------------------
          1  recursive calls
          0  db block gets
        312  consistent gets
          0  physical reads
          0  redo size
        420  bytes sent via SQL*Net to client
        415  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
          1  rows processed
```

The big difference here is that the `HASH JOIN ANTI SNA` plan has significantly less consistent gets: 312 vs. 14,137,436 - over a 45,000x difference!!!  Hence the 12 minutes to less than 1 second execution time.  I think it is quite safe to say that the `HASH JOIN ANTI SNA` is much better than the `FILTER` plan.

As demonstrated, the **Null-Aware Anti-Join** query transformation can have a significant performance, even on two tables consisting of a modest 100,000 rows of data.
