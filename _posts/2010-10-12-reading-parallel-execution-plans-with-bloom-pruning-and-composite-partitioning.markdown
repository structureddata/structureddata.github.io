---
author: Greg Rahn
comments: true
date: 2010-10-12T16:00:41.000Z
layout: post
slug: reading-parallel-execution-plans-with-bloom-pruning-and-composite-partitioning
title: Reading Parallel Execution Plans With Bloom Pruning And Composite Partitioning
wp_id: 1189
wp_categories:
  - Data Warehousing
  - Execution Plans
  - Optimizer
  - Oracle
  - Parallel Execution
  - Performance
  - SQL Tuning
  - Troubleshooting
  - VLDB
wp_tags:
  - Bloom Filter
  - Bloom Pruning
  - Execution Plans
  - Optimizer
  - Parallel Execution
---

You've probably heard sayings like  "sometimes things aren't always what they seem" and "people lie".  Well, sometimes execution plans lie.  It's not really by intent, but it is sometimes difficult (or impossible) to represent everything in a query execution tree in nice tabular format like dbms_xplan gives.

One of the optimizations that was introduced back in 10gR2 was the use of [bloom filters](http://en.wikipedia.org/wiki/Bloom_filter).  Bloom filters can be used in two ways: 1) for filtering or 2) for partition pruning (bloom pruning) starting with 11g.  Frequently the data models used in data warehousing are [dimensional models](http://en.wikipedia.org/wiki/Dimensional_modeling) (star or snowflake) and most Oracle warehouses use simple range (or interval) partitioning on the fact table date key column as that is the filter that yields the largest I/O reduction from partition pruning (most queries in a time series star schema include a time window, right!).  As a result, it is imperative that the join between the date dimension and the fact table results in partition pruning.

Let's consider a basic two table join between a date dimension and a fact table.  For these examples I'm using STORE_SALES and DATE_DIM which are [TPC-DS](http://www.tpc.org/tpcds/tpcds.asp) tables (I frequently use TPC-DS for experiments as it uses a dimensional (star) model and has a data generator.) STORE_SALES contains a 5 year window of data ranging from 1998-01-02 to 2003-01-02.

### Range Partitioned STORE_SALES

For this example I used range partitioning on STORE_SALES.SS_SOLD_DATE_SK using 60 one month partitions (plus 1 partition for `NULL` SS_SOLD_DATE_SK values) that align with the date dimension (DATE_DIM) on calendar month boundaries. STORE_SALES has the parallel attribute (PARALLEL 16 in this case) set on the table to enable Oracle's Parallel Execution (PX).  Let's look at the execution time and plan for our test query:

```
SQL> select
  2    max(ss_sales_price)
  3  from
  4    store_sales ss,
  5    date_dim d
  6  where
  7    ss_sold_date_sk = d_date_sk and
  8    d_year = 2000
  9  ;

MAX(SS_SALES_PRICE)
-------------------
                200

Elapsed: 00:00:41.67

SQL> select * from table(dbms_xplan.display_cursor(format=>'basic +parallel +partition +predicate'));

PLAN_TABLE_OUTPUT
--------------------------------------------------------------------------------------------------
EXPLAINED SQL STATEMENT:
------------------------
select   max(ss_sales_price) from   store_sales ss,   date_dim d where
 ss_sold_date_sk=d_date_sk and   d_year = 2000

Plan hash value: 934332680

---------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name         | Pstart| Pstop |    TQ  |IN-OUT| PQ Distrib |
--------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |             |       |       |        |      |            |
|   1 |  SORT AGGREGATE               |             |       |       |        |      |            |
|   2 |   PX COORDINATOR              |             |       |       |        |      |            |
|   3 |    PX SEND QC (RANDOM)        | :TQ10001    |       |       |  Q1,01 | P->S | QC (RAND)  |
|   4 |     SORT AGGREGATE            |             |       |       |  Q1,01 | PCWP |            |
|*  5 |      HASH JOIN                |             |       |       |  Q1,01 | PCWP |            |
|   6 |       BUFFER SORT             |             |       |       |  Q1,01 | PCWC |            |
|   7 |        PART JOIN FILTER CREATE| :BF0000     |       |       |  Q1,01 | PCWP |            |
|   8 |         PX RECEIVE            |             |       |       |  Q1,01 | PCWP |            |
|   9 |          PX SEND BROADCAST    | :TQ10000    |       |       |        | S->P | BROADCAST  |
|* 10 |           TABLE ACCESS FULL   | DATE_DIM    |       |       |        |      |            |
|  11 |       PX BLOCK ITERATOR       |             |:BF0000|:BF0000|  Q1,01 | PCWC |            |
|* 12 |        TABLE ACCESS FULL      | STORE_SALES |:BF0000|:BF0000|  Q1,01 | PCWP |            |
--------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   5 - access("SS_SOLD_DATE_SK"="D_DATE_SK")
  10 - filter("D_YEAR"=2000)
  12 - access(:Z>=:Z AND :Z<=:Z)
```
In this execution plan you can see the creation of the bloom filter on line 7 which is populated from the values of D_DATE_SK from DATE_DIM.  That bloom filter is then used to partition prune on the STORE_SALES table.  This is why we see `:BF0000` in the `Pstart`/`Pstop` columns. 

### Range-Hash Composite Partitioned STORE_SALES

For the next experiment, I kept the same range partitioning scheme but also added hash subpartitioning using the SS_ITEM_SK column (using 4 hash subpartitions per range partition).  STORE_SALES2 has 61 range partitions x 4 hash subpartitions for a total of 244 aggregate partitions.  Let's look at the execution plan for our test query:

```
SQL> select
  2    max(ss_sales_price)
  3  from
  4    store_sales2 ss,
  5    date_dim d
  6  where
  7    ss_sold_date_sk = d_date_sk and
  8    d_year = 2000
  9  ;

MAX(SS_SALES_PRICE)
-------------------
                200

Elapsed: 00:00:41.06

SQL> select * from table(dbms_xplan.display_cursor(format=>'basic +parallel +partition +predicate'));

PLAN_TABLE_OUTPUT
--------------------------------------------------------------------------------------------------
EXPLAINED SQL STATEMENT:
------------------------
select   max(ss_sales_price) from   store_sales2 ss,   date_dim d where
  ss_sold_date_sk=d_date_sk and   d_year = 2000

Plan hash value: 2496395846

---------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name         | Pstart| Pstop |    TQ  |IN-OUT| PQ Distrib |
---------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |              |       |       |        |      |            |
|   1 |  SORT AGGREGATE               |              |       |       |        |      |            |
|   2 |   PX COORDINATOR              |              |       |       |        |      |            |
|   3 |    PX SEND QC (RANDOM)        | :TQ10001     |       |       |  Q1,01 | P->S | QC (RAND)  |
|   4 |     SORT AGGREGATE            |              |       |       |  Q1,01 | PCWP |            |
|*  5 |      HASH JOIN                |              |       |       |  Q1,01 | PCWP |            |
|   6 |       BUFFER SORT             |              |       |       |  Q1,01 | PCWC |            |
|   7 |        PART JOIN FILTER CREATE| :BF0000      |       |       |  Q1,01 | PCWP |            |
|   8 |         PX RECEIVE            |              |       |       |  Q1,01 | PCWP |            |
|   9 |          PX SEND BROADCAST    | :TQ10000     |       |       |        | S->P | BROADCAST  |
|* 10 |           TABLE ACCESS FULL   | DATE_DIM     |       |       |        |      |            |
|  11 |       PX BLOCK ITERATOR       |              |     1 |     4 |  Q1,01 | PCWC |            |
|* 12 |        TABLE ACCESS FULL      | STORE_SALES2 |     1 |   244 |  Q1,01 | PCWP |            |
---------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   5 - access("SS_SOLD_DATE_SK"="D_DATE_SK")
  10 - filter("D_YEAR"=2000)
  12 - access(:Z>=:Z AND :Z<=:Z)
```

Once again you can see the creation of the bloom filter from DATE_DIM on line 7, however you will notice that we no longer see `:BF0000` as our `Pstart` and `Pstop` values.  In fact, it may appear that partition pruning is not taking place at all as we see 1/244 as our `Pstart`/`Pstop` values.  However, if we compare the execution times between the range and range/hash queries you note they are identical to the nearest second, thus there really is no way that partition (bloom) pruning is not taking place.  After all, if this plan read all 5 years of data it would take 5 times as long as reading just 1 year and that certainly is not the case.  Would you have guessed that partition pruning is taking place had we not worked though the range only experiment first?  Hmmm...

### So What Is Going On?

Before we dive in, let's quickly look at what the execution plans would look like if PX was not used (using serial execution).

```
--
-- Range Partitioned, Serial Execution
--

---------------------------------------------------------------------
| Id  | Operation                     | Name        | Pstart| Pstop |
---------------------------------------------------------------------
|   0 | SELECT STATEMENT              |             |       |       |
|   1 |  SORT AGGREGATE               |             |       |       |
|*  2 |   HASH JOIN                   |             |       |       |
|   3 |    PART JOIN FILTER CREATE    | :BF0000     |       |       |
|*  4 |     TABLE ACCESS FULL         | DATE_DIM    |       |       |
|   5 |    PARTITION RANGE JOIN-FILTER|             |:BF0000|:BF0000|
|   6 |     TABLE ACCESS FULL         | STORE_SALES |:BF0000|:BF0000|
---------------------------------------------------------------------
              
--
-- Range-Hash Composite Partitioned, Serial Execution
--
                                       
----------------------------------------------------------------------
| Id  | Operation                     | Name         | Pstart| Pstop |
----------------------------------------------------------------------
|   0 | SELECT STATEMENT              |              |       |       |
|   1 |  SORT AGGREGATE               |              |       |       |
|*  2 |   HASH JOIN                   |              |       |       |
|   3 |    PART JOIN FILTER CREATE    | :BF0000      |       |       |
|*  4 |     TABLE ACCESS FULL         | DATE_DIM     |       |       |
|   5 |    PARTITION RANGE JOIN-FILTER|              |:BF0000|:BF0000|
|   6 |     PARTITION HASH ALL        |              |     1 |     4 |
|   7 |      TABLE ACCESS FULL        | STORE_SALES2 |     1 |   244 |
----------------------------------------------------------------------

```

When using composite partitioning, pruning is placed on one of the partition iterators. When the two nested partition iterators (range/hash in this case) are changed into a block iterator (line 14 -` PX BLOCK ITERATOR`), we have to pick a "victim" in the query plan tree since only one node in the plan needs now to carry the pruning information (with PX the pruning is really done by the QC, not the row source like in serial plans).  As a result, the information associated the the victimized partition iterator is lost in the explain plan.  This is why there is no `:BF0000` for `Pstart`/`Pstop` in the plan in this case.  It is probably more accurate to have the parallel plans for both range and range/hash look like this:

```
---------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name         | Pstart| Pstop |    TQ  |IN-OUT| PQ Distrib |
---------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |              |       |       |        |      |            |
|   1 |  SORT AGGREGATE               |              |       |       |        |      |            |
|   2 |   PX COORDINATOR              |              |       |       |        |      |            |
|   3 |    PX SEND QC (RANDOM)        | :TQ10001     |       |       |  Q1,01 | P->S | QC (RAND)  |
|   4 |     SORT AGGREGATE            |              |       |       |  Q1,01 | PCWP |            |
|*  5 |      HASH JOIN                |              |       |       |  Q1,01 | PCWP |            |
|   6 |       BUFFER SORT             |              |       |       |  Q1,01 | PCWC |            |
|   7 |        PART JOIN FILTER CREATE| :BF0000      |       |       |  Q1,01 | PCWP |            |
|   8 |         PX RECEIVE            |              |       |       |  Q1,01 | PCWP |            |
|   9 |          PX SEND BROADCAST    | :TQ10000     |       |       |        | S->P | BROADCAST  |
|* 10 |           TABLE ACCESS FULL   | DATE_DIM     |       |       |        |      |            |
|  11 |       PX BLOCK ITERATOR       |              |       |       |  Q1,01 | PCWC |            |
|* 12 |        TABLE ACCESS FULL      | STORE_SALES  |:BF0000|:BF0000|  Q1,01 | PCWP |            |
---------------------------------------------------------------------------------------------------

```

Where the bloom pruning is on the `TABLE ACCESS FULL` row source.  This is because there is no Pstart/Pstop for a `PX BLOCK ITERATOR` row source (it's block ranges, so partition information is lost - it had been contained in level above this).

Hopefully this helps you understand and correctly identify execution plans contain bloom pruning even though at first glance you may not think they do.  If you are uncertain, use the execution stats for the query looking at metrics like amount of data read and execution times to provide some empirical insight.
