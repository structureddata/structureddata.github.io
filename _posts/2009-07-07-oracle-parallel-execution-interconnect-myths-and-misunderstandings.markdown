---
author: Greg Rahn
comments: true
date: 2009-07-07T00:00:17.000Z
layout: post
slug: oracle-parallel-execution-interconnect-myths-and-misunderstandings
title: 'Oracle Parallel Execution: Interconnect Myths And Misunderstandings'
wp_id: 602
wp_categories:
  - Data Warehousing
  - Oracle
  - Parallel Execution
  - Performance
  - VLDB
wp_tags:
  - interconnect traffic
  - Parallel Execution
  - parallel query
---

A number of weeks back I had come across a paper/presentation by [Riyaj Shamsudeen](http://orainternals.wordpress.com/) entitled _Battle of the Nodes: RAC Performance Myths_ ([avaiable here](http://orainternals.wordpress.com/my-papers-and-presentations/)).  As I was looking through it I saw one example that struck me as very odd  (Myth #3 - Interconnect Performance) and I contacted him about it.  [After further review](http://orainternals.wordpress.com/2009/06/20/rac-parallel-query-and-udpsnoop/) Riyaj commented that he had made a mistake in his analysis and offered up a new example.  I thought I'd take the time to discuss this as parallel execution seems to be one of those areas where many misconceptions and misunderstandings exist.

### The Original Example

I thought I'd quickly discuss why I questioned the initial example.  The original query Riyaj cited is this one:

```
select /*+ full(tl) parallel (tl,4) */
       avg (n1),
       max (n1),
       avg (n2),
       max (n2),
       max (v1)
from   t_large tl;
```

As you can see this is a very simple single table aggregation without a group by.  The reason that I questioned the validity of this example in the context of interconnect performance is that the parallel execution servers (parallel query slaves) will each return exactly one row from the aggregation and then send that single row to the query coordinator (QC) which will then perform the final aggregation.  Given that, it would seem impossible that this query could cause any interconnect issues at all.

### Riyaj's Test Case #1

Recognizing the original example was somehow flawed, Riyaj came up with a new example (I'll reference as TC#1) which consisted of the following query: 

```
select /*+ parallel (t1, 8,2) parallel (t2, 8, 2)  */
       min (t1.customer_trx_line_id + t2.customer_trx_line_id),
       max (t1.set_of_books_id + t2.set_of_books_id),
       avg (t1.set_of_books_id + t2.set_of_books_id),
       avg (t1.quantity_ordered + t2.quantity_ordered),
       max (t1.attribute_category),
       max (t2.attribute1),
       max (t1.attribute2)
from   (select *
        from   big_table
        where  rownum &amp;lt;= 100000000) t1,
       (select *
        from   big_table
        where  rownum &amp;lt;= 100000000) t2
where  t1.customer_trx_line_id = t2.customer_trx_line_id;

```

The execution plan for this query is:

```
----------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                 | Name      | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib |
----------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT          |           |     1 |   249 |       |  2846K  (4)| 01:59:01 |        |      |            |
|   1 |  SORT AGGREGATE           |           |     1 |   249 |       |            |          |        |      |            |
|*  2 |   HASH JOIN               |           |   100M|    23G|   762M|  2846K  (4)| 01:59:01 |        |      |            |
|   3 |    VIEW                   |           |   100M|    10G|       |  1214K  (5)| 00:50:46 |        |      |            |
|*  4 |     COUNT STOPKEY         |           |       |       |       |            |          |        |      |            |
|   5 |      PX COORDINATOR       |           |       |       |       |            |          |        |      |            |
|   6 |       PX SEND QC (RANDOM) | :TQ10000  |   416M|  6749M|       |  1214K  (5)| 00:50:46 |  Q1,00 | P->S | QC (RAND)  |
|*  7 |        COUNT STOPKEY      |           |       |       |       |            |          |  Q1,00 | PCWC |            |
|   8 |         PX BLOCK ITERATOR |           |   416M|  6749M|       |  1214K  (5)| 00:50:46 |  Q1,00 | PCWC |            |
|   9 |          TABLE ACCESS FULL| BIG_TABLE |   416M|  6749M|       |  1214K  (5)| 00:50:46 |  Q1,00 | PCWP |            |
|  10 |    VIEW                   |           |   100M|    12G|       |  1214K  (5)| 00:50:46 |        |      |            |
|* 11 |     COUNT STOPKEY         |           |       |       |       |            |          |        |      |            |
|  12 |      PX COORDINATOR       |           |       |       |       |            |          |        |      |            |
|  13 |       PX SEND QC (RANDOM) | :TQ20000  |   416M|    10G|       |  1214K  (5)| 00:50:46 |  Q2,00 | P->S | QC (RAND)  |
|* 14 |        COUNT STOPKEY      |           |       |       |       |            |          |  Q2,00 | PCWC |            |
|  15 |         PX BLOCK ITERATOR |           |   416M|    10G|       |  1214K  (5)| 00:50:46 |  Q2,00 | PCWC |            |
|  16 |          TABLE ACCESS FULL| BIG_TABLE |   416M|    10G|       |  1214K  (5)| 00:50:46 |  Q2,00 | PCWP |            |
----------------------------------------------------------------------------------------------------------------------------
Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("T1"."n1"="T2"."n1")
   4 - filter(ROWNUM<=100000000)
   7 - filter(ROWNUM<=100000000)
  11 - filter(ROWNUM<=100000000)
  14 - filter(ROWNUM<=100000000)
```

This is a rather synthetic query but there are a few things that I would like to point out.  First, this query uses a parallel hint with 3 values representing table/degree/instances, however instances has been deprecated (see [10.2 parallel hint documentation](http://download.oracle.com/docs/cd/B10501_01/server.920/a96540/sql_elements7a.htm#8477)).  In this case the DOP is calculated by degree * instances or 16, not DOP=8 involving 2 instances.   Note that the rownum filter is causing all the rows from the tables to be sent back to the QC for the `COUNT STOPKEY` operation thus causing the execution plan to serialize, denoted by the `P->S` in the `IN-OUT` column.

Riyaj had enabled sql trace for the QC and the TKProf output is such:

```
Rows     Row Source Operation
-------  ---------------------------------------------------
      1  SORT AGGREGATE (cr=152 pr=701158 pw=701127 time=1510221226 us)
98976295   HASH JOIN  (cr=152 pr=701158 pw=701127 time=1244490336 us)
100000000    VIEW  (cr=76 pr=0 pw=0 time=200279054 us)
100000000     COUNT STOPKEY (cr=76 pr=0 pw=0 time=200279023 us)
100000000      PX COORDINATOR  (cr=76 pr=0 pw=0 time=100270084 us)
      0       PX SEND QC (RANDOM) :TQ10000 (cr=0 pr=0 pw=0 time=0 us)
      0        COUNT STOPKEY (cr=0 pr=0 pw=0 time=0 us)
      0         PX BLOCK ITERATOR (cr=0 pr=0 pw=0 time=0 us)
      0          TABLE ACCESS FULL BIG_TABLE_NAME_CHANGED_12 (cr=0 pr=0 pw=0 time=0 us)
100000000    VIEW  (cr=76 pr=0 pw=0 time=300298770 us)
100000000     COUNT STOPKEY (cr=76 pr=0 pw=0 time=200298726 us)
100000000      PX COORDINATOR  (cr=76 pr=0 pw=0 time=200279954 us)
      0       PX SEND QC (RANDOM) :TQ20000 (cr=0 pr=0 pw=0 time=0 us)
      0        COUNT STOPKEY (cr=0 pr=0 pw=0 time=0 us)
      0         PX BLOCK ITERATOR (cr=0 pr=0 pw=0 time=0 us)
      0          TABLE ACCESS FULL BIG_TABLE_NAME_CHANGED_12 (cr=0 pr=0 pw=0 time=0 us)
```

Note that the Rows column contains zeros for many of the row sources because this trace is only for the QC, not the slaves, and thus only QC rows will show up in the trace file.  Something to be aware of if you decide to use sql trace with parallel execution.

### Off To The Lab: Myth Busting Or Bust!

I wanted to take a query like TC#1 and run it in my own environment so I could do more monitoring of it.  Given the alleged myth had to do with interconnect traffic of cross-instance (inter-node) parallel execution, I wanted to be certain to gather the appropriate data.  I ran several tests using a similar query on a similar sized data set (by row count) as the initial example.  I ran all my experiments on a Oracle Real Application Clusters version 11.1.0.7 consisting of eight nodes, each with two quad-core CPUs.  The interconnect is InfiniBand and the protocol used is RDS (Reliable Datagram Sockets).

Before I get into the experiments I think it is worth mentioning that Oracle's parallel execution (PX), which includes Parallel Query (PQ), PDML & PDDL, can consume vast amounts of resources.  This is by design.  You see, the idea of Oracle PX is to dedicate a large amount of resources (processes) to a problem by breaking it up into many smaller pieces and then operate on those pieces in parallel.  Thus the more parallelism that is used to solve a problem, the more resources it will consume, assuming those resources are available.  That should be fairly obvious, but I think it is worth stating.

For my experiments I used a table that contains just over 468M rows.

Below is my version of TC#1.  The query is a self-join on a unique key and the table is range partitioned by DAY_KEY into 31 partitions.  Note that I create a AWR snapshot immediately before and after the query.

```
exec dbms_workload_repository.create_snapshot

select /* &1 */
       /*+ parallel (t1, 16) parallel (t2, 16) */
       min (t1.bsns_unit_key + t2.bsns_unit_key),
       max (t1.day_key + t2.day_key),
       avg (t1.day_key + t2.day_key),
       max (t1.bsns_unit_typ_cd),
       max (t2.curr_ind),
       max (t1.load_dt)
from   dwb_rtl_trx t1,
       dwb_rtl_trx t2
where  t1.trx_nbr = t2.trx_nbr;

exec dbms_workload_repository.create_snapshot
```

### Experiment Results Using Fixed DOP=16

I ran my version of TC#1 across a varying number of nodes by using Oracle services (instance_groups and parallel_instance_group have been deprecated in 11g), but kept the DOP constant at 16 for all the tests.  Below is a table of the experiment results.

Nodes | Elapsed Time | SQL Monitor Report | AWR Report | AWR SQL Report
--- | --- | --- | --- | --- 
1 | 00:04:54.12 | [a6r9zzu06tudh.htm](/assets/pq/range/1/a6r9zzu06tudh.htm) | [awrrpt_1_910_911.html](/assets/assets/pq/range/1/awrrpt_1_910_911.html) | [awrsqlrpt_1_910_911.html](/assets/assets/pq/range/1/awrsqlrpt_1_910_911.html)
2 | 00:03:55.35 | [54patfpds4pp3.htm](/assets/pq/range/2/54patfpds4pp3.htm) | [awrrpt_2_912_913.html](/assets/assets/pq/range/2/awrrpt_2_912_913.html) | [awrsqlrpt_2_912_913.html](/assets/assets/pq/range/2/awrsqlrpt_2_912_913.html)
4 | 00:02:59.24 | [dgyay259941s4.htm](/assets/pq/range/4/dgyay259941s4.htm) | [awrrpt_4_914_915.html](/assets/assets/pq/range/4/awrrpt_4_914_915.html) | [awrsqlrpt_4_914_915.html](/assets/assets/pq/range/4/awrsqlrpt_4_914_915.html)
8 | 00:02:14.39 | [7b1a4ngy9q7kc.htm](/assets/pq/range/8/7b1a4ngy9q7kc.htm) | [awrrpt_3_916_917.html](/assets/assets/pq/range/8/awrrpt_3_916_917.html) | [awrsqlrpt_3_916_917.html](/assets/assets/pq/range/8/awrsqlrpt_3_916_917.html)


Seemingly contrary to what many people would probably guess, the execution times got better the more nodes that participated in the query even though the DOP constant throughout each of tests.

### Measuring The Interconnect Traffic

One of the new additions to the AWR report in 11g was the inclusion of interconnect traffic by client.  This section is near the bottom of the report and looks like such: 
![Interconnect Throughput By Client](/assets/pq/InterconnectThroughputByClient.png) 
This allows the PQ message traffic to be tracked, whereas in prior releases it was not.

Even though AWR contains the throughput numbers (as in megabytes per second) I thought it would be interesting to see how much data was being transferred, so I used the following query directly against the AWR data.  I put a filter predicate on to return only where there DIFF_RECEIVED_MB >= 10MB so the instances that were not part of the execution are filtered out, as well as the single instance execution.

```
break on snap_id skip 1
compute sum of DIFF_RECEIVED_MB on SNAP_ID
compute sum of DIFF_SENT_MB on SNAP_ID

select *
from   (select   snap_id,
                 instance_number,
                 round ((bytes_sent - lag (bytes_sent, 1) over
                   (order by instance_number, snap_id)) / 1024 / 1024) diff_sent_mb,
                 round ((bytes_received - lag (bytes_received, 1) over
                   (order by instance_number, snap_id)) / 1024 / 1024) diff_received_mb
        from     dba_hist_ic_client_stats
        where    name = 'ipq' and
                 snap_id between 910 and 917
        order by snap_id,
                 instance_number)
where  snap_id in (911, 913, 915, 917) and
       diff_received_mb >= 10
/

SNAP_ID    INSTANCE_NUMBER DIFF_SENT_MB DIFF_RECEIVED_MB
---------- --------------- ------------ ----------------
       913               1        11604            10688
                         2        10690            11584
**********                 ------------ ----------------
sum                               22294            22272

       915               1         8353             8350
                         2         8133             8418
                         3         8396             8336
                         4         8514             8299
**********                 ------------ ----------------
sum                               33396            33403

       917               1         5033             4853
                         2         4758             4888
                         3         4956             4863
                         4         5029             4852
                         5         4892             4871
                         6         4745             4890
                         7         4753             4889
                         8         4821             4881
**********                 ------------ ----------------
sum                               38987            38987
```

As you can see from the data, the more nodes that were involved in the execution, the more interconnect traffic there was, however, the execution times were best with 8 nodes.

### Further Explanation Of Riyaj's Issue

If you read Riyaj's post, you noticed that he observed worse, not better as I did, elapsed times when running on two nodes versus one.  How could this be?  It was noted in the comment thread of that post that the configuration was using Gig-E as the interconnect in a Solaris IPMP active-passive configuration.  This means the interconnect speeds would be capped at 128MB/s (1000Mbps), the wire speed of Gig-E.  This is by all means is an inadequate configuration to use cross-instance parallel execution.

There is a whitepaper entitled [_Oracle SQL Parallel Execution_](http://www.oracle.com/technology/products/bi/db/11g/pdf/twp_bidw_parallel_execution_11gr1.pdf) that discusses many of the aspects of Oracle's parallel execution.  I would highly recommend reading it.  This paper specifically mentions:

> If you use a relatively weak interconnect, relative to the I/O bandwidth from the server to the storage configuration, then you may be better of restricting parallel execution to a single node or to a limited number of nodes; inter-node parallel execution will not scale with an undersized interconnect.

I would assert that this is precisely the root cause (insufficient interconnect bandwidth for cross-instance PX) behind the issues that Riyaj observed, thus making his execution slower on two nodes than one node.

### The Advantage Of Hash Partitioning/Subpartitioning And Full Partition-Wise Joins

At the end of [my comment](http://orainternals.wordpress.com/2009/06/20/rac-parallel-query-and-udpsnoop/#comment-328) on Riyaj's blog, I mentioned:

> If a DW frequently uses large table to large table joins, then hash partitioning or subpartitioning would yield added gains as partition-wise joins will be used.

I thought that it would be both beneficial and educational to extend TC#1 and implement hash subpartitioning so that the impact could be measured on both query elapsed time and interconnect traffic.  In order for a full partition-wise join to take place, the table must be partitioned/subpartitioned on the join key column, so in this case I've hash subpartitioned on TRX_NBR.  See the [Oracle Documentation on Partition-Wise Joins](http://download.oracle.com/docs/cd/B28359_01/server.111/b32024/part_avail.htm#sthref414) for a more detailed discussion on PWJ.

### Off To The Lab: Partition-Wise Joins

I've run through the exact same test matrix with the new range/hash partitioning model and below are the results.

Nodes | Elapsed Time | SQL Monitor Report | AWR Report | AWR SQL Report |
--- | --- | --- | --- | --- |
1 | 00:02:42.41 | [arty65g64fmt7.htm](/assets/pq/range-hash/1/arty65g64fmt7.htm) | [awrrpt_1_1041_1042.html](/assets/pq/range-hash/1/awrrpt_1_1041_1042.html) | [awrsqlrpt_1_1041_1042.html](/assets/pq/range-hash/1/awrsqlrpt_1_1041_1042.html) |
2 | 00:01:37.29 | [crqv3q3x9rtgt.htm](/assets/pq/range-hash/2/crqv3q3x9rtgt.htm) | [awrrpt_2_1043_1044.html](/assets/pq/range-hash/2/awrrpt_2_1043_1044.html) | [awrsqlrpt_2_1043_1044.html](/assets/pq/range-hash/2/awrsqlrpt_2_1043_1044.html) |
4 | 00:01:12.82 | [5yv7yvjgjxugg.htm](/assets/pq/range-hash/4/5yv7yvjgjxugg.htm) | [awrrpt_4_1045_1046.html](/assets/pq/range-hash/4/awrrpt_4_1045_1046.html) | [awrsqlrpt_4_1045_1046.html](/assets/pq/range-hash/4/awrsqlrpt_4_1045_1046.html) |
8 | 00:01:05.04 | [8dkv0z9wm9881.htm](/assets/pq/range-hash/8/8dkv0z9wm9881.htm) | [awrrpt_3_1047_1048.html](/assets/pq/range-hash/8/awrrpt_3_1047_1048.html) | [awrsqlrpt_3_1047_1048.html](/assets/pq/range-hash/8/awrsqlrpt_3_1047_1048.html) |

As you can see by the elapsed times, the range/hash partitioning model with the full partition-wise join has decreased the overall execution time by around a factor of 2X compared to the range only partitioned version.

Now let's take a look at the interconnect traffic for the PX messages:

```
break on snap_id skip 1
compute sum of DIFF_RECEIVED_MB on SNAP_ID
compute sum of DIFF_SENT_MB on SNAP_ID

select *
from   (select   snap_id,
                 instance_number,
                 round ((bytes_sent - lag (bytes_sent, 1) over
                   (order by instance_number, snap_id)) / 1024 / 1024) diff_sent_mb,
                 round ((bytes_received - lag (bytes_received, 1) over
                   (order by instance_number, snap_id)) / 1024 / 1024) diff_received_mb
        from     dba_hist_ic_client_stats
        where    name = 'ipq' and
                 snap_id between 1041 and 1048
        order by snap_id,
                 instance_number)
where  snap_id in (1042,1044,1046,1048) and
       diff_received_mb >= 10
/
no rows selected
```

Hmm.  No rows selected?!?  I had previously put in the predicate `DIFF_RECEIVED_MB >= 10MB` to filter out the nodes that were not participating in the parallel execution.  Let me remove that predicate rerun the query.

```
   SNAP_ID INSTANCE_NUMBER DIFF_SENT_MB DIFF_RECEIVED_MB
---------- --------------- ------------ ----------------
      1042               1            8                6
                         2            2                3
                         3            2                3
                         4            2                3
                         5            2                3
                         6            2                3
                         7            2                3
                         8            2                3
**********                 ------------ ----------------
sum                                  22               27

      1044               1            7                7
                         2            3                2
                         3            2                2
                         4            2                2
                         5            2                2
                         6            2                2
                         7            2                2
                         8            2                2
**********                 ------------ ----------------
sum                                  22               21

      1046               1            1                2
                         2            1                2
                         3            1                2
                         4            3                1
                         5            1                1
                         6            1                1
                         7            1                1
                         8            1                1
**********                 ------------ ----------------
sum                                  10               11

      1048               1            6                5
                         2            1                2
                         3            3                2
                         4            1                2
                         5            1                2
                         6            1                2
                         7            1                2
                         8            1                2
**********                 ------------ ----------------
sum                                  15               19
```

Wow, there is almost no interconnect traffic at all.  Let me verify with the AWR report from the 8 node execution.

![](/assets/pq/8node-pwj-ic-traffic.png)

The AWR report confirms that there is next to no interconnect traffic for the PWJ version of TC#1.  The reason for this is that since the table is hash subpartitoned on the join column each of the subpartitions can be joined to each other minimizing the data sent between parallel execution servers.  If you look at the execution plan (see the AWR SQL Report) from the first set of experiments you will notice that the broadcast method for each of the tables is HASH but in the range/hash version of TC#1 there is no broadcast at all for either of the two tables.  The full partition-wise join behaves logically the same way that a shared-nothing database would; each of the parallel execution servers works on its partition which does not require data from any other partition because of the hash partitioning on the join column.  The main difference is that in a shared-nothing database the data is physically hash distributed amongst the nodes (each node contains a subset of all the data) where as all nodes in a Oracle RAC database have access to the all the data.

### Parting Thoughts

Personally I see no myth about cross-instance (inter-node) parallel execution and interconnect traffic, but frequently I see misunderstandings and misconceptions.  As shown by the data in my experiment, TC#1 (w/o hash subpartitioning) running on eight nodes is more than 2X faster than running on one node using exactly the same DOP.  Interconnect traffic is not a bad thing as long as the interconnect is designed to support the workload.  Sizing the interconnect is really no different than sizing any other component of your cluster (memory/CPU/disk space/storage bandwidth).  If it is undersized, performance will suffer.  Depending on the number and speed of the host CPUs and the speed and bandwidth of the interconnect, your results may vary.

By hash subpartioning the table the interconnect traffic was all but eliminated and the query execution times were around 2X faster than the non-hash subpartition version of TC#1.  This is obviously a much more scalable solution and one of the main reasons to leverage hash (sub)partitioning in a data warehouse.
