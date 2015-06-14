---
author: Greg Rahn
comments: true
date: 2007-10-24T02:00:50.000Z
layout: post
slug: bloom-filters
title: Bloom Filters
wp_id: 32
wp_categories:
  - Execution Plans
  - Optimizer
  - Oracle
  - SQL Tuning
wp_tags:
  - Bloom Filter
  - partial partition-wise join
---

The other day I was reading the [11g Database VLDB and Partitioning Guide](http://download.oracle.com/docs/cd/B28359_01/server.111/b32024/part_avail.htm) and came across the [below execution plan](http://download.oracle.com/docs/cd/B28359_01/server.111/b32024/part_avail.htm#sthref426) for a partial partition-wise join between sales and customers.

```
---------------------------------------------------------------------------
| Id  | Operation                             | Name      | Pstart| Pstop |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT                      |           |       |       |
|   1 |  PX COORDINATOR                       |           |       |       |
|   2 |   PX SEND QC (RANDOM)                 | :TQ10002  |       |       |
|*  3 |    FILTER                             |           |       |       |
|   4 |     HASH GROUP BY                     |           |       |       |
|   5 |      PX RECEIVE                       |           |       |       |
|   6 |       PX SEND HASH                    | :TQ10001  |       |       |
|   7 |        HASH GROUP BY                  |           |       |       |
|*  8 |         HASH JOIN                     |           |       |       |
|   9 |          PART JOIN FILTER CREATE      | :BF0000   |       |       |
|  10 |           PX RECEIVE                  |           |       |       |
|  11 |            PX SEND PARTITION (KEY)    | :TQ10000  |       |       |
|  12 |             PX BLOCK ITERATOR         |           |       |       |
|  13 |              TABLE ACCESS FULL        | CUSTOMERS |       |       |
|  14 |          PX PARTITION HASH JOIN-FILTER|           |:BF0000|:BF0000|
|* 15 |           TABLE ACCESS FULL           | SALES     |:BF0000|:BF0000|
---------------------------------------------------------------------------
Predicate Information (identified by operation id):
---------------------------------------------------
   3 - filter(COUNT(SYS_OP_CSR(SYS_OP_MSR(COUNT(*)),0))>100)
   8 - access("S"."CUST_ID"="C"."CUST_ID")
  15 - filter("S"."TIME_ID"=TO_DATE(' 1999-07-01 00:00:00',
                                     'syyyy-mm-dd hh24:mi:ss'))
```

At first, it may seem just like another parallel execution plan, but if you look again you may notice that the Pstart and Pstop values are `:BF0000` (id 15) and `:BF0000` also appears on as part of the `PART JOIN FILTER CREATE` (id 9).  So what exactly is `:BF0000`?  This is a [bloom filter](http://en.wikipedia.org/wiki/Bloom_filter) being applied as part of the DFO (data flow operator).

It's not necessary to completely understand bloom filters to take advantage of them, but the next time you see `:BF0000` in your parallel execution plan, you will be able to recognize what it is.
