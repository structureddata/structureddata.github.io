---
author: Greg Rahn
comments: true
date: 2010-01-25T12:00:01.000Z
layout: post
slug: the-core-performance-fundamentals-of-oracle-data-warehousing-partitioning
title: The Core Performance Fundamentals Of Oracle Data Warehousing - Partitioning
wp_id: 816
wp_categories:
  - Data Warehousing
  - Oracle
  - Performance
  - VLDB
wp_tags:
  - Data Warehousing
  - managability
  - Oracle
  - partitioning
  - Performance
---

[back to [Introduction](/2009/12/14/the-core-performance-fundamentals-of-oracle-data-warehousing-introduction/)]

Partitioning is an essential performance feature for an Oracle data warehouse because partition elimination (or partition pruning) generally results in the elimination of a significant amount of table data to be scanned.  This results in a need for less system resources and improved query performance.  Someone once told me "_**the fastest I/O is the one that never happens**_." This is precisely the reason that partitioning is a must for Oracle data warehouses - it's a huge I/O eliminator.  I frequently refer to partition elimination as the anti-index.  An index is used to find a small amount data that _is_ required; partitioning is used to eliminate vasts amounts of data that _is not_ required.

### Main Uses For Partitioning

I would classify the main reasons to use partitioning in your Oracle data warehouse into these four areas:

- Data Elimination
- Partition-Wise Joins
- Manageability (Partition Exchange Load, Local Indexes, etc.)
- Information Lifecycle Management (ILM)

### Partitioning Basics

The most common partitioning design pattern found in Oracle data warehouses is to partition the fact tables by range (or interval) on the event date/time column.  This allows for partition elimination of all the data not in the desired time window in queries.  For example: If I have a fact table that contains point of sale (POS) data, each line item  for a given transaction has a time stamp of when the item was scanned.  Let's say this value is stored in column EVENT_TS which is a DATE or TIMESTAMP data type.  In most cases it would make sense to partition by range on EVENT_TS using one day partitions.  This means every query that uses a predicate filter on EVENT_TS (which should be nearly every one) can eliminate significant amounts of data that is not required to satisfy the query predicate.  If you want to look at yesterday's sales numbers, there is no need to bring back rows from last week or last month!

### Subpartitioning Options

Depending on the schema design of your data warehouse you may also chose to subpartition a table.  This allows one to further segment a table to allow for even more data elimination or it can allow for [partition-wise joins](http://download.oracle.com/docs/cd/E11882_01/server.112/e10837/part_warehouse.htm#VLDBG1347) which allow for reduced usage of CPU and memory resources by minimizing the amount of data exchanged between parallel execution server processes.  In [third normal form (3NF) schemas](http://download.oracle.com/docs/cd/E11882_01/server.112/e10810/schemas.htm#DWHSG8584) it is very beneficial to use hash partitioning or subpartitioning to allow for partition-wise joins  (see [Oracle Parallel Execution: Interconnect Myths And Misunderstandings](/2009/07/06/oracle-parallel-execution-interconnect-myths-and-misunderstandings/)) for this exact reason.  Dimensional models ([star schemas](http://download.oracle.com/docs/cd/E11882_01/server.112/e10810/schemas.htm#DWHSG8587)) may also benefit from hash subpartitioning and partition-wise joins.  Generally it is best to hash subpartition on a join key column to a very large dimension, like CUSTOMER, so that a partition-wise join will be used between the fact table and the large dimension table.

### Manageability

Managing large objects can be challenging for a variety of reasons which is why Oracle Partitioning allows for many operations to be done at a global or partition (or subpartition) level.  This makes it much easier to deal with tables or indexes of large sizes.  It also is transparent to applications so the SQL that runs against a non-partitioned object will run as-is against a partitioned object.  Some of the key features include:

- **Partition Exchange Load** - Data can be loaded "out of line" and exchanged into a partitioned table.
- **Local Indexes** - It takes much less time to build local indexes than global indexes.
- **Compression** - Can be applied at the segment level so it's possible to have a mix of compressed and non-compressed partitions.
- **Segment Moves/Rebuilds/Truncates/Drops** - Each partition (or subpartition) is a segment and can be operated on individually and independently of the other partitions in the table.
- **Information Lifecycle Management (ILM)** - Partitioning allows implementation of an ILM strategy.

### Summary

I'd classify partitioning as a "must have" for Oracle data warehouses for both the performance and manageability reasons described above. Partitioning should lower query response time as well as resource utilization do to "smart" data access (only go after the data the query needs). There are additional partitioning design patterns as well and the Oracle documentation contains descriptions of them as well as examples.

### Oracle Documentation References:

- [VLDB and Partitioning Guide: Using Partitioning in a Data Warehouse Environment](http://download.oracle.com/docs/cd/E11882_01/server.112/e10837/part_warehouse.htm)
- [VLDB and Partitioning Guide: Recommendations for Choosing a Partitioning Strategy](http://download.oracle.com/docs/cd/E11882_01/server.112/e10837/part_avail.htm)
- [VLDB and Partitioning Guide: Partitioning for Availability, Manageability, and Performance](http://download.oracle.com/docs/cd/E11882_01/server.112/e10837/part_avail.htm#VLDBG00406)
- [Partitioning in Oracle Database 10_g_ Release 2](http://www.oracle.com/technology/products/bi/db/10g/pdf/twp_general_partitioning_10gr2_0505.pdf)
