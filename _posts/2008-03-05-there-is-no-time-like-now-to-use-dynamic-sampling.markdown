---
author: Greg Rahn
comments: true
date: 2008-03-05T09:00:16.000Z
layout: post
slug: there-is-no-time-like-now-to-use-dynamic-sampling
title: "There Is No Time Like '%NOW%' To Use Dynamic Sampling"
wp_id: 57
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
  - VLDB
wp_tags:
  - '5% selectivity'
  - cardinality
  - dynamic sampling
  - Optimizer
---

I recently came across a query in which the Optimizer was making a poor cardinality estimate, which in turn caused  inefficient join type, which in turn caused the query to run excessively long.  This post is a reenactment of my troubleshooting.

### The Suspect SQL

The original SQL was quite large and had a fairly complex plan so I simplified it down to this test case for the purpose of this blog post: 

```
select [...]
from   fact_table al1
where  al1.region = '003' and
       al1.order_type = 'Z010' and
       al1.business_type in ('002', '003', '007', '009') and
       (not (al1.cust_po like '%MATERIAL HANDLING%' or
             al1.cust_po like '%SECURITY%' or
             al1.cust_po like '%SUMMER OF CREATIVITY%' or
             al1.cust_po like '%TEST%'));

----------------------------------------------------------------------------
| Id  | Operation                            | Name                | Rows  |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT                     |                     |     1 |
|   1 |  SORT AGGREGATE                      |                     |     1 |
|   2 |   PARTITION LIST SINGLE              |                     |     9 |
|   3 |    PARTITION HASH ALL                |                     |     9 |
|*  4 |     TABLE ACCESS BY LOCAL INDEX ROWID| FACT_TABLE          |     9 |
|   5 |      BITMAP CONVERSION TO ROWIDS     |                     |       |
|*  6 |       BITMAP INDEX SINGLE VALUE      | FACT_BX10           |       |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter("AL1"."CUST_PO" NOT LIKE '%MATERIAL HANDLING%' AND
              "AL1"."CUST_PO" NOT LIKE '%SECURITY%' AND
              "AL1"."CUST_PO" NOT LIKE '%SUMMER OF CREATIVITY%' AND
              "AL1"."CUST_PO" NOT LIKE '%TEST%')
   6 - access("AL1"."ORDER_TYPE"='Z010')
```

Looking at the plan I would surmise that the cardinality estimate for the fact table (line 4) must surely be greater than 9.  To find out how far the Optimizer's guess is off, I ran this query which contained all the filter predicates for FACT_TABLE:

```
select count(*)
from   fact_table al1
where  al1.region = '003' and
       al1.order_type = 'Z010' and
       (not (al1.cust_po like '%MATERIAL HANDLING%' or
             al1.cust_po like '%SECURITY%' or
             al1.cust_po like '%SUMMER OF CREATIVITY%' or
             al1.cust_po like '%TEST%'));

  COUNT(*)
----------
 1,324,510
```

As you can see, the cardinality estimate in this case is way off.  The Optimizer estimated 9 rows and in reality the query returns 1.3 million rows, _only_ a difference of 6 orders of magnitude (10^6 or 1,000,000).  How could this be? Let's try and understand why and where the cardinality estimate went wrong.

## Bite Size Chunks

I find the easiest way to debug these issues is to use start with one predicate then add one predicate at a time, noting the cardinality estimate and comparing it to the actual cardinality value.

### One Predicate, Two Predicate, Red Predicate, Blue Predicate

```
explain plan for
select count (*)
from   fact_table al1
where  al1.region = '003'
/
select *
from table(dbms_xplan.display(format=>'BASIC ROWS PREDICATE'));

--------------------------------------------------------------
| Id  | Operation              | Name                | Rows  |
--------------------------------------------------------------
|   0 | SELECT STATEMENT       |                     |     1 |
|   1 |  SORT AGGREGATE        |                     |     1 |
|   2 |   PARTITION LIST SINGLE|                     |   141M|
|   3 |    PARTITION HASH ALL  |                     |   141M|
|   4 |     TABLE ACCESS FULL  | FACT_TABLE          |   141M|
--------------------------------------------------------------

   COUNT(*)
-----------
141,821,991
```

Looks good so far.  REGION is the list partition key so we'd expect an accurate estimate.

```
explain plan for
select count (*)
from   fact_table al1
where  al1.region = '003' and
       al1.order_type = 'Z010'
/
select *
from table(dbms_xplan.display(format=>'BASIC ROWS PREDICATE'));

------------------------------------------------------------
| Id  | Operation                     | Name       | Rows  |
------------------------------------------------------------
|   0 | SELECT STATEMENT              |            |     1 |
|   1 |  SORT AGGREGATE               |            |     1 |
|   2 |   PARTITION LIST SINGLE       |            |  1456K|
|   3 |    PARTITION HASH ALL         |            |  1456K|
|   4 |     BITMAP CONVERSION COUNT   |            |  1456K|
|*  5 |      BITMAP INDEX SINGLE VALUE| FACT_BX10  |       |
------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   5 - access("AL1"."ORDER_TYPE"='Z010')

  COUNT(*)
----------
 1,324,642
```

No issues here.  1,456,000 statistically equivalent to 1,324,642.

```
explain plan for
select count (*)
from   fact_table al1
where  al1.region = '003' and
       al1.order_type = 'Z010' and
       (not (al1.cust_po like '%MATERIAL HANDLING%'))
/
select *
from table(dbms_xplan.display(format=>'BASIC ROWS PREDICATE'));

----------------------------------------------------------------------------
| Id  | Operation                            | Name                | Rows  |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT                     |                     |     1 |
|   1 |  SORT AGGREGATE                      |                     |     1 |
|   2 |   PARTITION LIST SINGLE              |                     | 72803 |
|   3 |    PARTITION HASH ALL                |                     | 72803 |
|*  4 |     TABLE ACCESS BY LOCAL INDEX ROWID| FACT_TABLE          | 72803 |
|   5 |      BITMAP CONVERSION TO ROWIDS     |                     |       |
|*  6 |       BITMAP INDEX SINGLE VALUE      | FACT_BX10           |       |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter("AL1"."CUST_PO" NOT LIKE '%MATERIAL HANDLING%')
   6 - access("AL1"."ORDER_TYPE"='Z010')

  COUNT(*)
----------
 1,324,642
```

With the addition of the `NOT LIKE` predicate we start to see a bit of a difference.  This plan has a 20x reduction from the previous cardinality estimate (1,456,000/72,803  = 20).  Let's add one more `NOT LIKE` predicate and see what we get.

```
explain plan for
select count (*)
from   fact_table al1
where  al1.region = '003' and
       al1.order_type = 'Z010' and
       (not (al1.cust_po like '%MATERIAL HANDLING%' or
             al1.cust_po like '%SECURITY%'))
/
select *
from table(dbms_xplan.display(format=>'BASIC ROWS PREDICATE'));

----------------------------------------------------------------------------
| Id  | Operation                            | Name                | Rows  |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT                     |                     |     1 |
|   1 |  SORT AGGREGATE                      |                     |     1 |
|   2 |   PARTITION LIST SINGLE              |                     |  3640 |
|   3 |    PARTITION HASH ALL                |                     |  3640 |
|*  4 |     TABLE ACCESS BY LOCAL INDEX ROWID| FACT_TABLE          |  3640 |
|   5 |      BITMAP CONVERSION TO ROWIDS     |                     |       |
|*  6 |       BITMAP INDEX SINGLE VALUE      | FACT_BX10           |       |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter("AL1"."CUST_PO" NOT LIKE '%MATERIAL HANDLING%' AND
              "AL1"."CUST_PO" NOT LIKE '%SECURITY%')
   6 - access("AL1"."ORDER_TYPE"='Z010')


  COUNT(*)
----------
 1,324,642
```

With the addition of a second `NOT LIKE` predicate the cardinality estimate has dropped to 3,640 from 72,803, a 20x reduction.

```
explain plan for
select count (*)
from   fact_table al1
where  al1.region = '003' and
       al1.order_type = 'Z010' and
       (not (al1.cust_po like '%MATERIAL HANDLING%' or
             al1.cust_po like '%SECURITY%' or
             al1.cust_po like '%SUMMER OF CREATIVITY%'))
/
select *
from table(dbms_xplan.display(format=>'BASIC ROWS PREDICATE'));

----------------------------------------------------------------------------
| Id  | Operation                            | Name                | Rows  |
----------------------------------------------------------------------------
|   0 | SELECT STATEMENT                     |                     |     1 |
|   1 |  SORT AGGREGATE                      |                     |     1 |
|   2 |   PARTITION LIST SINGLE              |                     |   182 |
|   3 |    PARTITION HASH ALL                |                     |   182 |
|*  4 |     TABLE ACCESS BY LOCAL INDEX ROWID| FACT_TABLE          |   182 |
|   5 |      BITMAP CONVERSION TO ROWIDS     |                     |       |
|*  6 |       BITMAP INDEX SINGLE VALUE      | FACT_BX10           |       |
----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter("AL1"."CUST_PO" NOT LIKE '%MATERIAL HANDLING%' AND
              "AL1"."CUST_PO" NOT LIKE '%SECURITY%' AND
              "AL1"."CUST_PO" NOT LIKE '%SUMMER OF CREATIVITY%')
   6 - access("AL1"."ORDER_TYPE"='Z010')

   COUNT(*)
----------
 1,324,642
```

With the addition of the third `NOT LIKE` predicate the cardinality estimate has dropped from 3,640 to 182, another 20x reduction.  Looks like we may have found the issue.  Each `NOT LIKE` predicate appears to result in a 20x reduction (5% selectivity) from the previous estimate.  The original query had all four `NOT LIKE` predicates on it and had a cardinality estimate of 9.  If we work the math: 182 * 5% = 9.

Looking at the query we can see there are four `NOT LIKE` predicates each with a leading and trailing wild card (%).  Since `DBMS_STATS` does not gather table column information on parts of strings, each of the `NOT LIKE` predicates will have a default selectivity guess of 5%.  Given this query has four `NOT LIKE` predicates, the total reduction for those four predicates will be 5%^4 = 1/160,000 = 0.00000625 which is quite significant, and in this case not representative and the root cause of the original query's suboptimal access and join type.

### Dynamic Sampling To The Rescue

[Dynamic Sampling](http://download.oracle.com/docs/cd/B28359_01/server.111/b28274/stats.htm#i42991) was designed with cases like this in mind.  That is, cases where the Optimizer has to resort to selectivity guesses and could very well guess poorly.  Substring guessing is not simply done as the substring could appear anywhere in the string.  Let's see what the cardinality estimate is when I add a dynamic_sampling hint to the query.

```
explain plan for
select /*+ dynamic_sampling(al1 4) */
       count (*)
from   fact_table al1
where  al1.region = '003' and
       al1.order_type = 'Z010' and
       (not (al1.cust_po like '%MATERIAL HANDLING%' or
             al1.cust_po like '%SECURITY%' or
             al1.cust_po like '%SUMMER OF CREATIVITY%' or
             al1.cust_po like '%TEST%'))
/
select *
from table(dbms_xplan.display(format=>'BASIC ROWS PREDICATE NOTE'));

--------------------------------------------------------------
| Id  | Operation              | Name                | Rows  |
--------------------------------------------------------------
|   0 | SELECT STATEMENT       |                     |     1 |
|   1 |  SORT AGGREGATE        |                     |     1 |
|   2 |   PARTITION LIST SINGLE|                     |  1606K|
|   3 |    PARTITION HASH ALL  |                     |  1606K|
|*  4 |     TABLE ACCESS FULL  | FACT_TABLE          |  1606K|
--------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter("AL1"."ORDER_TYPE"='Z010' AND
              "AL1"."CUST_PO" NOT LIKE '%MATERIAL HANDLING%' AND
              "AL1"."CUST_PO" NOT LIKE '%SECURITY%' AND
              "AL1"."CUST_PO" NOT LIKE '%SUMMER OF CREATIVITY%' AND
              "AL1"."CUST_PO" NOT LIKE '%TEST%')

Note
-----
   - dynamic sampling used for this statement
```

With a level 4 `dynamic_sampling` hint the Optimizer estimates 1.6 million rows, very close to the actual value of 1.3 million rows.  This estimate is surely close enough to give us the optimal access and join type such that the original query should perform optimally.

### Summary

There are case where the Optimizer guesses and sometimes can guess poorly.  When this is the case, dynamic sampling can be used to give the Optimizer a better cardinality guess.  Dynamic sampling is probably best suited for queries that run minutes or longer, such that the overhead of the dynamic sampling query is only a fraction of the total run time.  In these cases, the minimal overhead of dynamic sampling can well out weigh the cost of a suboptimal plan.

All tests were performed on 11.1.0.6.0.
