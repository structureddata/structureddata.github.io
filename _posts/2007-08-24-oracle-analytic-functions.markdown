---
author: Greg Rahn
comments: true
date: 2007-08-24T09:28:30.000Z
layout: post
slug: oracle-analytic-functions
title: Oracle Analytic Functions
wp_id: 23
wp_categories:
  - Data Warehousing
  - Execution Plans
  - Optimizer
  - Oracle
  - Performance
  - SQL Tuning
---

Recently, I've been quite busy with performance projects and haven't had the spare time I would like to keep up on my blog.  Now that those projects are behind me, I wanted to blog about the use of one feature that made a significant difference in performance on a number of queries for this project. This feature was the [Oracle Analytic Functions](http://download.oracle.com/docs/cd/B19306_01/server.102/b14200/functions001.htm#SQLRF06174).  This functionality has been present since Oracle 8.1.6 and enhancements have been made to them from release to release.  For those of you with an OLTP background, the [Oracle Analytic Functions ](http://download.oracle.com/docs/cd/B19306_01/server.102/b14200/functions001.htm#SQLRF06174)may be somewhat unfamiliar, but those with a data warehousing background are hopefully leveraging these functions.  One powerful benefit of the [Oracle Analytic Functions](http://download.oracle.com/docs/cd/B19306_01/server.102/b14200/functions001.htm#SQLRF06174) is that the aggregation and windowing can usually be done in a single pass over the table.

I've chosen one example that I consider a more complex one.  It was more complex than I had previously worked with, so I had to turn to an Oracle developer that specializes in the [Oracle Analytic Functions](http://download.oracle.com/docs/cd/B19306_01/server.102/b14200/functions001.htm#SQLRF06174) to get the answers and thus would like to share them with the Oracle user community.

### The Original Query

Let's look at the original query:

``` sql
SELECT P.PRS_ID,
       P.GEO_CD,
       P.OBLIGATION_ID,
       P.ORDER_NR,
       P.COUNTRY_NM,
       P.REGION_NM,
       P.ORDER_CRE_TS,
       P.PREV_OBL_TS1,
       CASE
         WHEN (Q.ORDER_CRE_TS BETWEEN
               NVL(P.PREV_OBL_TS,P.ORDER_CRE_TS)
               AND P.ORDER_CRE_TS)
         THEN NULL
         ELSE P.PREV_OBL_TS
       END PREV_OBL_TS
FROM   TAB2 P,
       TAB1 Q
WHERE  P.PRS_ID = Q.PRS_ID
       AND Q.ORDER_CRE_TS BETWEEN
           NVL(P.PREV_OBL_TS,Q.ORDER_CRE_TS)
       AND (SELECT MAX(ORDER_CRE_TS)
            FROM   TAB1 C
            WHERE  P.PRS_ID = C.PRS_ID
                   AND C.ORDER_CRE_TS > P.PREV_OBL_TS
                   AND C.ORDER_CRE_TS <= P.ORDER_CRE_TS);
```

This appears to be a pretty basic two table query with a simple subquery that is looking for a max timestamp for a given `PRS_ID`.

If we take a look at the execution plan for this query you will notice that the subquery is causing a second pass to TAB1 as there are no indexes on either table.

```
---------------------------------------
| Id  | Operation             | Name  |
---------------------------------------
|   0 | SELECT STATEMENT      |       |
|*  1 |  FILTER               |       |
|   2 |   HASH GROUP BY       |       |
|*  3 |    HASH JOIN          |       |
|*  4 |     HASH JOIN         |       |
|   5 |      TABLE ACCESS FULL| TAB2  |
|   6 |      TABLE ACCESS FULL| TAB1  |
|   7 |     TABLE ACCESS FULL | TAB1  |
---------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------
   1 - filter("Q"."ORDER_CRE_TS"=NVL("P"."PREV_OBL_TS","Q"."ORDER_CRE_TS"))
   4 - access("P"."PRS_ID"="C"."PRS_ID")
       filter(("C"."ORDER_CRE_TS">"P"."PREV_OBL_TS" AND
              "C"."ORDER_CRE_TS"<="P"."ORDER_CRE_TS"))
```

A first, quick reaction might be to recommend to put an index on `TAB1(PRS_ID,ORDER_CRE_TS)`, such that the subquery could be satisfied with an index-only lookup.  The challenge here is that we have a pretty big data set w/o much data elimination (say >200,000,000 rows) from the `TAB1`/`TAB2` table join and if we were to use an index it would probably cause the execution plan to do a nested-loops join which would probably be pretty slow, but perhaps faster than a second full table scan of `TAB1`.  Adding that index is probably also considered a "custom solution" because we don't know how many other ad-hoc queries in this data warehouse could leverage this index, if any.  Adding "custom" indexes in a data warehouse could also become a problem as the more indexes that exist, the slower the loads are - even if partitioning is used with local index rebuilds.

### Now Enter Oracle Analytic Functions

The original query can be rewritten to leverage a window function.  Here is the rewritten query:

``` sql
SELECT PRS_ID,
       GEO_CD,
       OBLIGATION_ID,
       ORDER_NR,
       COUNTRY_NM,
       REGION_NM,
       ORDER_CRE_TS,
       PREV_OBL_TS1,
       PREV_OBL_TS
FROM   (SELECT P.PRS_ID,
               P.GEO_CD,
               P.OBLIGATION_ID,
               P.ORDER_NR,
               P.COUNTRY_NM,
               P.REGION_NM,
               P.ORDER_CRE_TS,
               P.PREV_OBL_TS1,
               CASE
                 WHEN (Q.ORDER_CRE_TS BETWEEN
                       NVL(P.PREV_OBL_TS,P.ORDER_CRE_TS)
                       AND P.ORDER_CRE_TS) THEN NULL
                 ELSE P.PREV_OBL_TS
               END PREV_OBL_TS,
               NVL(P.PREV_OBL_TS,Q.ORDER_CRE_TS)  NVL_DATE,
               Q.ORDER_CRE_TS                     Q_ORDER_CRE_TS,
               MAX(CASE
                     WHEN Q.ORDER_CRE_TS > P.PREV_OBL_TS
                          AND Q.ORDER_CRE_TS = NVL_DATE
       AND Q_ORDER_CRE_TS <= MAX_ORDER_CRE_TS;
```

Notice the original subquery for the `MAX(ORDER_CRE_TS)` has been incorporated into the `MAX(CASE WHEN) OVER PARTITION BY)` clause and the original date filter is now applied in the outer select query.

Now lets look at the execution plan for the rewritten query:

```
--------------------------------------
| Id  | Operation            | Name  |
--------------------------------------
|   0 | SELECT STATEMENT     |       |
|*  1 |  VIEW                |       |
|   2 |   WINDOW SORT        |       |
|*  3 |    HASH JOIN         |       |
|   4 |     TABLE ACCESS FULL| TAB2  |
|   5 |     TABLE ACCESS FULL| TAB1  |
--------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------
   1 - filter(("Q_ORDER_CRE_TS">="NVL_DATE" AND
              "Q_ORDER_CRE_TS"<="MAX_ORDER_CRE_TS"))
   3 - access("P"."PRS_ID"="Q"."PRS_ID")
```

The requirement for the second pass to TAB1 in the original query has now been eliminated and the `MAX()` is able to be done in a single pass using a `WINDOW SORT`.

Another alternative is to manually push part of the date filter predicate to the inner select.

``` sql
SELECT PRS_ID,
       GEO_CD,
       OBLIGATION_ID,
       ORDER_NR,
       COUNTRY_NM,
       REGION_NM,
       ORDER_CRE_TS,
       PREV_OBL_TS1,
       PREV_OBL_TS
FROM   (SELECT P.PRS_ID,
               P.GEO_CD,
               P.OBLIGATION_ID,
               P.ORDER_NR,
               P.COUNTRY_NM,
               P.REGION_NM,
               P.ORDER_CRE_TS,
               P.PREV_OBL_TS1,
               CASE
                 WHEN (Q.ORDER_CRE_TS BETWEEN
                       NVL(P.PREV_OBL_TS,P.ORDER_CRE_TS)
                       AND P.ORDER_CRE_TS)
                 THEN NULL
                 ELSE P.PREV_OBL_TS
               END PREV_OBL_TS,
               Q.ORDER_CRE_TS   Q_ORDER_CRE_TS,
               MAX(CASE
                     WHEN Q.ORDER_CRE_TS > P.PREV_OBL_TS
                          AND Q.ORDER_CRE_TS = NVL(P.PREV_OBL_TS,Q.ORDER_CRE_TS))
WHERE  Q_ORDER_CRE_TS <= MAX_ORDER_CRE_TS;

--------------------------------------
| Id  | Operation            | Name  |
--------------------------------------
|   0 | SELECT STATEMENT     |       |
|*  1 |  VIEW                |       |
|   2 |   WINDOW SORT        |       |
|*  3 |    HASH JOIN         |       |
|   4 |     TABLE ACCESS FULL| TAB2  |
|   5 |     TABLE ACCESS FULL| TAB1  |
--------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("Q_ORDER_CRE_TS"=NVL("P"."PREV_OBL_TS","Q"."ORDER_CRE_TS"))
```

In this case we get exactly the same execution plan but personally I like to push predicates as deep as possible even though the Optimizer may choose to do it as well.

### Summary

As demonstrated by example, the [Oracle Analytic Functions](http://download.oracle.com/docs/cd/B19306_01/server.102/b14200/functions001.htm#SQLRF06174) are quite powerful from a Business Intelligence point of view as well as a performance view.  I would encourage leveraging them as much as possible in a data warehouse environment.
