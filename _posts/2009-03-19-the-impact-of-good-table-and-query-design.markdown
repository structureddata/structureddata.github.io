---
author: Greg Rahn
comments: true
date: 2009-03-19T10:00:24.000Z
layout: post
slug: the-impact-of-good-table-and-query-design
title: The Impact Of Good Table And Query Design
wp_id: 436
wp_categories:
  - 11gR1
  - Data Warehousing
  - Execution Plans
  - Oracle
  - SQL Tuning
  - VLDB
wp_tags:
  - pivot
  - pivot table
  - star schema
  - table design
  - unpivot
---

There are many ways to design tables/schemas and many ways to write SQL queries that execute against those tables/schemas.  Some designs are better than others for various reasons, however, I think that frequently people underestimate the power of SQL (for both "good" and "evil").  All too often in data warehouses, I see tables designed for one specific report, or a very select few reports.  These tables frequently resemble Microsoft Excel Spreadsheets (generally Pivot Tables), not good Dimensional (Star Schema) or Third Normal Form (3NF) schema design.  The problem with such designs is that it severely limits the usefulness of that data, as queries that were not known at the time of design often time become problematic.  The following is a simple one table example, derived from a field experience in which I discuss two table designs and provide the SQL queries to answer a question the business is seeking.

### The Business Question

First lets start with the business question for which the answer is being sought. What customers meet the following criteria:

- do not own PRODUCT1 or PRODUCT2 but have downloaded SOFTWARE
- do not own PRODUCT2 and it has been more than 90 days between SOFTWARE download and their purchase of PRODUCT1

### Version 1: The Column Based (Pivot) Table Design

For Version 1, there is a single row for each customer and each attribute has its own column.  In this case there are 4 columns, each representing the most recent activity date for that product.

```
SQL> desc column_tab
 Name                                      Null?    Type
 ----------------------------------------- -------- ----------------------------
 CUSTOMER_ID                               NOT NULL NUMBER
 SOFTWARE_MAC_RECENCY_TS                            DATE
 SOFTWARE_WIN_RECENCY_TS                            DATE
 PRODUCT1_RECENCY_TS                                DATE
 PRODUCT2_RECENCY_TS                                DATE

SQL> select * from column_tab;

CUSTOMER_ID SOFTWARE_M SOFTWARE_W PRODUCT1_R PRODUCT2_R
----------- ---------- ---------- ---------- ----------
        100 2009-03-17            2008-11-17
        200 2009-03-17            2009-01-16
        300 2009-03-17            2008-10-08 2009-02-25
        400            2009-03-17 2008-11-07
        500 2009-03-17

5 rows selected.

SQL> select customer_id
  2  from   column_tab
  3  where  product2_recency_ts is null and
  4         (((software_win_recency_ts is not null or
  5            software_mac_recency_ts is not null) and
  6           product1_recency_ts is null) or
  7          ((software_win_recency_ts - product1_recency_ts) > 90 or
  8           (software_mac_recency_ts - product1_recency_ts) > 90));

CUSTOMER_ID
-----------
        100
        400
        500

3 rows selected.

Execution Plan
----------------------------------------------------------
Plan hash value: 4293700422

--------------------------------------------------------------------------------
| Id  | Operation         | Name       | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |            |     2 |    42 |     3   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| COLUMN_TAB |     2 |    42 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("PRODUCT2_RECENCY_TS" IS NULL AND ("PRODUCT1_RECENCY_TS"
              IS NULL AND ("SOFTWARE_MAC_RECENCY_TS" IS NOT NULL OR
              "SOFTWARE_WIN_RECENCY_TS" IS NOT NULL) OR
              "SOFTWARE_MAC_RECENCY_TS"-"PRODUCT1_RECENCY_TS">90 OR
              "SOFTWARE_WIN_RECENCY_TS"-"PRODUCT1_RECENCY_TS">90))
```
As you can see, the query construct to answer the business question is straight forward and requires just one pass over the table.

### Version 2: The Row Based (Unpivot) Table, Take 1

In Version 2, there is a single row (tuple) which tracks the customer, product and the recency date.  Unlike Version 1, none of the columns can be `NULL`.

```
SQL> desc row_tab
 Name                                      Null?    Type
 ----------------------------------------- -------- ----------------------------
 CUSTOMER_ID                               NOT NULL NUMBER
 RECENCY_TS                                NOT NULL DATE
 PRODUCT                                   NOT NULL VARCHAR2(32)

SQL> select * from row_tab;

CUSTOMER_ID RECENCY_TS PRODUCT
----------- ---------- --------------------------------
        100 2009-03-17 SOFTWARE_MAC
        200 2009-03-17 SOFTWARE_MAC
        300 2009-03-17 SOFTWARE_MAC
        500 2009-03-17 SOFTWARE_MAC
        400 2009-03-17 SOFTWARE_WIN
        100 2008-11-17 PRODUCT1
        200 2009-01-16 PRODUCT1
        300 2008-10-08 PRODUCT1
        400 2008-11-07 PRODUCT1
        300 2009-02-25 PRODUCT2

10 rows selected.

SQL> select a.customer_id
  2  from   row_tab a,
  3         (select customer_id,
  4                 product,
  5                 recency_ts
  6          from   row_tab
  7          where  product in ('SOFTWARE_MAC', 'SOFTWARE_WIN')) b
  8  where  a.customer_id not in (select customer_id
  9                               from   row_tab
 10                               where  product in ('PRODUCT1', 'PRODUCT2')) and
 11         a.customer_id = b.customer_id
 12  union
 13  select a.customer_id
 14  from   row_tab a,
 15         (select customer_id,
 16                 product,
 17                 recency_ts
 18          from   row_tab
 19          where  product in ('SOFTWARE_MAC', 'SOFTWARE_WIN')) b
 20  where  a.customer_id not in (select customer_id
 21                               from   row_tab
 22                               where  product = 'PRODUCT2') and
 23         a.customer_id = b.customer_id and
 24         (a.product = 'PRODUCT1' and
 25          b.recency_ts - a.recency_ts > 90);

CUSTOMER_ID
-----------
        100
        400
        500

3 rows selected.

Execution Plan
----------------------------------------------------------
Plan hash value: 3517586312

---------------------------------------------------------------------------------
| Id  | Operation             | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------
|   0 | SELECT STATEMENT      |         |    11 |   368 |    22  (60)| 00:00:01 |
|   1 |  SORT UNIQUE          |         |    11 |   368 |    22  (60)| 00:00:01 |
|   2 |   UNION-ALL           |         |       |       |            |          |
|*  3 |    HASH JOIN ANTI     |         |    10 |   310 |    10  (10)| 00:00:01 |
|*  4 |     HASH JOIN         |         |    11 |   187 |     7  (15)| 00:00:01 |
|*  5 |      TABLE ACCESS FULL| ROW_TAB |     5 |    70 |     3   (0)| 00:00:01 |
|   6 |      TABLE ACCESS FULL| ROW_TAB |    10 |    30 |     3   (0)| 00:00:01 |
|*  7 |     TABLE ACCESS FULL | ROW_TAB |     5 |    70 |     3   (0)| 00:00:01 |
|*  8 |    HASH JOIN ANTI     |         |     1 |    58 |    10  (10)| 00:00:01 |
|*  9 |     HASH JOIN         |         |     1 |    44 |     7  (15)| 00:00:01 |
|* 10 |      TABLE ACCESS FULL| ROW_TAB |     4 |    88 |     3   (0)| 00:00:01 |
|* 11 |      TABLE ACCESS FULL| ROW_TAB |     5 |   110 |     3   (0)| 00:00:01 |
|* 12 |     TABLE ACCESS FULL | ROW_TAB |     1 |    14 |     3   (0)| 00:00:01 |
---------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("A"."CUSTOMER_ID"="CUSTOMER_ID")
   4 - access("A"."CUSTOMER_ID"="CUSTOMER_ID")
   5 - filter("PRODUCT"='SOFTWARE_MAC' OR "PRODUCT"='SOFTWARE_WIN')
   7 - filter("PRODUCT"='PRODUCT1' OR "PRODUCT"='PRODUCT2')
   8 - access("A"."CUSTOMER_ID"="CUSTOMER_ID")
   9 - access("A"."CUSTOMER_ID"="CUSTOMER_ID")
       filter("RECENCY_TS"-"A"."RECENCY_TS">90)
  10 - filter("A"."PRODUCT"='PRODUCT1')
  11 - filter("PRODUCT"='SOFTWARE_MAC' OR "PRODUCT"='SOFTWARE_WIN')
  12 - filter("PRODUCT"='PRODUCT2')

```

### Version 2, Take 2

The way the query is written in Version 2, Take 1, it requires six accesses to the table.  Partly this is because it uses a `UNION`.  In this case the `UNION` can be removed and replaced with an `OR` branch.

```
SQL> select a.customer_id
  2  from   row_tab a,
  3         (select customer_id,
  4                 product,
  5                 recency_ts
  6          from   row_tab
  7          where  product in ('SOFTWARE_MAC', 'SOFTWARE_WIN')) b
  8  where  a.customer_id = b.customer_id and
  9         ((a.customer_id not in (select customer_id
 10                               from   row_tab
 11                               where  product in ('PRODUCT1', 'PRODUCT2')))
 12         or
 13         ((a.customer_id not in (select customer_id
 14                               from   row_tab
 15                               where  product = 'PRODUCT2') and
 16         (a.product = 'PRODUCT1' and
 17          b.recency_ts - a.recency_ts > 90))))
 18  /

CUSTOMER_ID
-----------
        100
        400
        500

3 rows selected.

Execution Plan
----------------------------------------------------------
Plan hash value: 3327813549

-------------------------------------------------------------------------------
| Id  | Operation           | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |         |     1 |    44 |     7  (15)| 00:00:01 |
|*  1 |  FILTER             |         |       |       |            |          |
|*  2 |   HASH JOIN         |         |    11 |   484 |     7  (15)| 00:00:01 |
|*  3 |    TABLE ACCESS FULL| ROW_TAB |     5 |   110 |     3   (0)| 00:00:01 |
|   4 |    TABLE ACCESS FULL| ROW_TAB |    10 |   220 |     3   (0)| 00:00:01 |
|*  5 |   TABLE ACCESS FULL | ROW_TAB |     1 |    14 |     3   (0)| 00:00:01 |
|*  6 |   TABLE ACCESS FULL | ROW_TAB |     1 |    14 |     3   (0)| 00:00:01 |
-------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter( NOT EXISTS (SELECT 0 FROM "ROW_TAB" "ROW_TAB" WHERE
              "CUSTOMER_ID"=:B1 AND ("PRODUCT"='PRODUCT1' OR "PRODUCT"='PRODUCT2'))
              OR  NOT EXISTS (SELECT 0 FROM "ROW_TAB" "ROW_TAB" WHERE
              "PRODUCT"='PRODUCT2' AND "CUSTOMER_ID"=:B2) AND
              "A"."PRODUCT"='PRODUCT1' AND "RECENCY_TS"-"A"."RECENCY_TS">90)
   2 - access("A"."CUSTOMER_ID"="CUSTOMER_ID")
   3 - filter("PRODUCT"='SOFTWARE_MAC' OR "PRODUCT"='SOFTWARE_WIN')
   5 - filter("CUSTOMER_ID"=:B1 AND ("PRODUCT"='PRODUCT1' OR
              "PRODUCT"='PRODUCT2'))
   6 - filter("PRODUCT"='PRODUCT2' AND "CUSTOMER_ID"=:B1)

```
This rewrite brings the table accesses down to four from six, so progress is being made, but I think we can do even better.

### Version 2, Take 3

SQL is a very powerful language and there is usually more than one way to structure a query.  Version 2, Take 1 uses a very literal translation of the business question and Take 2 just does a mild rewrite changing the `UNION` to an `OR`.  In Version 2, Take 3, I am going to leverage some different, but very powerful functionality to yield the same results.

```
SQL> -- COLUMN_TAB can be expressed using ROW_TAB with MAX + CASE WHEN + GROUP BY:
SQL> select   customer_id,
  2           max (case
  3                   when product = 'SOFTWARE_MAC'
  4                      then recency_ts
  5                end) software_mac_recency_ts,
  6           max (case
  7                   when product = 'SOFTWARE_WIN'
  8                      then recency_ts
  9                end) software_win_recency_ts,
 10           max (case
 11                   when product = 'PRODUCT1'
 12                      then recency_ts
 13                end) product1_recency_ts,
 14           max (case
 15                   when product = 'PRODUCT2'
 16                      then recency_ts
 17                end) product2_recency_ts
 18  from     row_tab
 19  group by customer_id;

CUSTOMER_ID SOFTWARE_M SOFTWARE_W PRODUCT1_R PRODUCT2_R
----------- ---------- ---------- ---------- ----------
        100 2009-03-17            2008-11-17
        200 2009-03-17            2009-01-16
        300 2009-03-17            2008-10-08 2009-02-25
        400            2009-03-17 2008-11-07
        500 2009-03-17

5 rows selected.

SQL> -- The original query can be expressed as follows:
SQL> select customer_id
  2  from   (select   customer_id,
  3                   max (case
  4                           when product = 'SOFTWARE_MAC'
  5                              then recency_ts
  6                        end) software_mac_recency_ts,
  7                   max (case
  8                           when product = 'SOFTWARE_WIN'
  9                              then recency_ts
 10                        end) software_win_recency_ts,
 11                   max (case
 12                           when product = 'PRODUCT1'
 13                              then recency_ts
 14                        end) product1_recency_ts,
 15                   max (case
 16                           when product = 'PRODUCT2'
 17                              then recency_ts
 18                        end) product2_recency_ts
 19          from     row_tab
 20          group by customer_id)
 21  where  product2_recency_ts is null and
 22         (((software_win_recency_ts is not null or
 23            software_mac_recency_ts is not null) and
 24           product1_recency_ts is null) or
 25          ((software_win_recency_ts - product1_recency_ts) > 90 or
 26           (software_mac_recency_ts - product1_recency_ts) > 90)
 27         );

CUSTOMER_ID
-----------
        100
        400
        500

3 rows selected.


Execution Plan
----------------------------------------------------------
Plan hash value: 825621652

-------------------------------------------------------------------------------
| Id  | Operation           | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |         |     1 |    22 |     4  (25)| 00:00:01 |
|*  1 |  FILTER             |         |       |       |            |          |
|   2 |   HASH GROUP BY     |         |     1 |    22 |     4  (25)| 00:00:01 |
|   3 |    TABLE ACCESS FULL| ROW_TAB |    10 |   220 |     3   (0)| 00:00:01 |
-------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter(MAX(CASE "PRODUCT" WHEN 'PRODUCT2' THEN "RECENCY_TS" END
              ) IS NULL AND ((MAX(CASE "PRODUCT" WHEN 'SOFTWARE_WIN' THEN
              "RECENCY_TS" END ) IS NOT NULL OR MAX(CASE "PRODUCT" WHEN
              'SOFTWARE_MAC' THEN "RECENCY_TS" END ) IS NOT NULL) AND MAX(CASE
              "PRODUCT" WHEN 'PRODUCT1' THEN "RECENCY_TS" END ) IS NULL OR MAX(CASE
              "PRODUCT" WHEN 'SOFTWARE_WIN' THEN "RECENCY_TS" END )-MAX(CASE
              "PRODUCT" WHEN 'PRODUCT1' THEN "RECENCY_TS" END )>90 OR MAX(CASE
              "PRODUCT" WHEN 'SOFTWARE_MAC' THEN "RECENCY_TS" END )-MAX(CASE
              "PRODUCT" WHEN 'PRODUCT1' THEN "RECENCY_TS" END )>90))

```
Rewriting the query as a `CASE WHEN` with a `GROUP BY` not only cleaned up the SQL, it also resulted in a single pass over the table.  Version 2, Take 3 reduces the table access from four to one!

### Version 2, Take 4: The PIVOT operator in 11g

In 11g the [`PIVOT` operator](http://download.oracle.com/docs/cd/B28359_01/server.111/b28313/analysis.htm#DWHSG0209) was introduced and can simplify the query even more.

```
SQL> -- In 11g the PIVOT operator can be used, so COLUMN_TAB can be expressed as:
SQL> select *
  2  from row_tab
  3  pivot (max(recency_ts) for product in
  4         ('SOFTWARE_MAC' as software_mac_recency_ts,
  5          'SOFTWARE_WIN' as software_win_recency_ts,
  6          'PRODUCT1' as product1_recency_ts,
  7          'PRODUCT2' as product2_recency_ts));

CUSTOMER_ID SOFTWARE_M SOFTWARE_W PRODUCT1_R PRODUCT2_R
----------- ---------- ---------- ---------- ----------
        100 2009-03-17            2008-11-17
        200 2009-03-17            2009-01-16
        300 2009-03-17            2008-10-08 2009-02-25
        400            2009-03-17 2008-11-07
        500 2009-03-17

5 rows selected.

SQL> -- Using PIVOT the original query can be expressed as:
SQL> select customer_id
  2  from   row_tab
  3  pivot  (max(recency_ts) for product in
  4         ('SOFTWARE_MAC' as software_mac_recency_ts,
  5          'SOFTWARE_WIN' as software_win_recency_ts,
  6          'PRODUCT1' as product1_recency_ts,
  7          'PRODUCT2' as product2_recency_ts))
  8  where  product2_recency_ts is null and
  9         (((software_win_recency_ts is not null or
 10            software_mac_recency_ts is not null) and
 11           product1_recency_ts is null) or
 12          ((software_win_recency_ts - product1_recency_ts) > 90 or
 13           (software_mac_recency_ts - product1_recency_ts) > 90)
 14         );

CUSTOMER_ID
-----------
        100
        400
        500

3 rows selected.

Execution Plan
----------------------------------------------------------
Plan hash value: 3127820873

--------------------------------------------------------------------------------
| Id  | Operation            | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------
|   0 | SELECT STATEMENT     |         |     1 |    22 |     4  (25)| 00:00:01 |
|*  1 |  FILTER              |         |       |       |            |          |
|   2 |   HASH GROUP BY PIVOT|         |     1 |    22 |     4  (25)| 00:00:01 |
|   3 |    TABLE ACCESS FULL | ROW_TAB |    10 |   220 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter(MAX(CASE  WHEN ("PRODUCT"='PRODUCT2') THEN "RECENCY_TS"
              END ) IS NULL AND ((MAX(CASE  WHEN ("PRODUCT"='SOFTWARE_WIN') THEN
              "RECENCY_TS" END ) IS NOT NULL OR MAX(CASE  WHEN
              ("PRODUCT"='SOFTWARE_MAC') THEN "RECENCY_TS" END ) IS NOT NULL) AND
              MAX(CASE  WHEN ("PRODUCT"='PRODUCT1') THEN "RECENCY_TS" END ) IS NULL
              OR MAX(CASE  WHEN ("PRODUCT"='SOFTWARE_WIN') THEN "RECENCY_TS" END
              )-MAX(CASE  WHEN ("PRODUCT"='PRODUCT1') THEN "RECENCY_TS" END )>90 OR
              MAX(CASE  WHEN ("PRODUCT"='SOFTWARE_MAC') THEN "RECENCY_TS" END
              )-MAX(CASE  WHEN ("PRODUCT"='PRODUCT1') THEN "RECENCY_TS" END )>90))

```

### The Big Picture

One thing that I did not touch on is the flexibility of the `ROW_TAB` design when it comes to evolution.  Any number of products can be added without making any modifications to the loading process.  In order to do this with the `COLUMN_TAB` a new column must be added for each new product.  The other major difference between the two table designs is that `ROW_TAB` is insert only while `COLUMN_TAB` must be updated if the customer exists.  Generally one wants to avoid updated in a data warehouse as 1) old data is usually over written and 2) updates are more expensive than inserts.

The other major thing I won't discuss in detail is how to partition or index (if required) `COLUMN_TAB`.  Think about this.  With `ROW_TAB` it is very straight forward.

### Summary

There are many ways to design tables and write queries.  Some of them work well, some do not.  Some appear impossible at first, only to appear more simple later.  Literal translation of a business question into SQL is usually far from optimal.  One needs to think about the question being asked, the shape of the data, and the options available to solve that problem as well as the trade offs of those solutions.  Remember: table definitions do not have to look like Spreadsheets.  Generally only the output of a query needs to.

Don't get stuck in SQL-92.  It is the year 2009.  You should be writing your SQL using the constructs that are provided.  Often times very complex data transformations can be done with just SQL.  Leverage this power.

All experiments performed on 11.1.0.7
