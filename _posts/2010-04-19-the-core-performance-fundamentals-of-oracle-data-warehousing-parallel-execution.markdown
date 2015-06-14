---
author: Greg Rahn
comments: true
date: 2010-04-19T15:00:25.000Z
layout: post
slug: the-core-performance-fundamentals-of-oracle-data-warehousing-parallel-execution
title: The Core Performance Fundamentals Of Oracle Data Warehousing - Parallel Execution
wp_id: 818
wp_categories:
  - Data Warehousing
  - Oracle
  - Parallel Execution
  - Performance
  - VLDB
wp_tags:
  - Data Warehousing
  - Oracle
  - Parallel Execution
  - parallel query
  - scalability
---

[back to [Introduction](/2009/12/14/the-core-performance-fundamentals-of-oracle-data-warehousing-introduction/)]

Leveraging Oracle's Parallel Execution (PX) in your Oracle data warehouse is probably the most important feature/technology one can use to speed up operations on large data sets.  PX is not, however, "go fast" magic pixi dust for any old operation (if thats what you think, you probably don't understand the parallel computing paradigm). With Oracle PX, a large task is broken up into smaller parts, sub-tasks if you will, and each sub-task is then worked on in parallel.  The goal of Oracle PX: divide and conquer. This allows a significant amount of hardware resources to be engaged in solving a single problem and is what allows the Oracle database to scale up and out when working with large data sets.

I though I'd touch on some basics and add my observations but this is by far not an exhaustive write up on Oracle's Parallel Execution.  There is an entire chapter in the [Oracle Database documentation](http://www.oracle.com/pls/db112/homepage) on PX as well as several white papers.  I've listed all these in the Resources section at the bottom of this post.  Read them, but as always, feel free to post questions/comments here.  Discussion adds great value.

### A Basic Example of Parallel Execution

Consider a simple one table query like the one below.

![](/assets/cncpt017.gif)

You can see that the PX Coordinator (also known as the Query Coordinator or QC) breaks up the "work" into several chunks and those chunks are worked on by the PX Server Processes.  The technical term for the chunk a PX Server Process works on is called a _granule_.  Granules can either be block-based or partition-based.

### When To Use Parallel Execution

PX is a key component in data warehousing as that is where large data sets usually exist.  The most common operations that use PX are queries (SELECTs) and data loads (INSERTs or CTAS).  PX is most commonly controlled by using the PARALLEL attribute on the object, although it can be controlled by hints or even Oracle's Database Resource Manager.  If you are not using PX in your Oracle data warehouse than you are probably missing out on a shedload of performance opportunity.

When an object has its PARALLEL attribute set or the [`PARALLEL` hint](http://download.oracle.com/docs/cd/E11882_01/server.112/e10592/sql_elements006.htm#SQLRF50801) is used queries will leverage PX, but to leverage PX for DML operations (INSERT/DELETE/UPDATE) remember to alter your session by using the command:

```
alter session [enable|force] parallel dml;
```

### Do Not Fear Parallel Execution

Since Oracle's PX is designed to take advantage of multiple CPUs (or CPU cores) at a time, it can leverage significant hardware resources, if available.  From my experiences in talking with Oracle DBAs, the ability for PX to do this scares them. This results in DBAs implementing a relatively small degree of parallelism (DOP) for a system that could possibly support a much higher level (based on #CPUs).  Often times though, the system that PX is being run on is not a [balanced system](/2009/12/22/the-core-performance-fundamentals-of-oracle-data-warehousing-balanced-hardware-configuration/) and frequently has much more CPU power than disk and channel bandwidth, so data movement from disk becomes the bottleneck well before the CPUs are busy.  This results in many statements like "Parallel Execution doesn't work" or similar because the user/DBA isn't observing a decrease in execution time with more parallelism.  Bottom line:  if the hardware resources are not available, the software certainly can not scale.

Just for giggles (and education), here is a snippet from [top(1)](http://linux.die.net/man/1/top) from a node from an Oracle Database Machine running a single query (across all 8 database nodes) at DOP 256.

```
top - 20:46:44 up 5 days,  3:48,  1 user,  load average: 36.27, 37.41, 35.75
Tasks: 417 total,  43 running, 373 sleeping,   0 stopped,   1 zombie
Cpu(s): 95.6%us,  1.6%sy,  0.0%ni,  2.2%id,  0.0%wa,  0.2%hi,  0.4%si,  0.0%st
Mem:  74027752k total, 21876824k used, 52150928k free,   440692k buffers
Swap: 16771852k total,        0k used, 16771852k free, 13770844k cached

USER       PID  PR  NI  VIRT  SHR  RES S %CPU %MEM    TIME+  COMMAND
oracle   16132  16   0 16.4g 5.2g 5.4g R 63.8  7.6 709:33.02 ora_p011_orcl
oracle   16116  16   0 16.4g 4.9g 5.1g R 60.9  7.2 698:35.63 ora_p003_orcl
oracle   16226  15   0 16.4g 4.9g 5.1g R 59.9  7.2 702:01.01 ora_p028_orcl
oracle   16110  16   0 16.4g 4.9g 5.1g R 58.9  7.2 697:20.51 ora_p000_orcl
oracle   16122  15   0 16.3g 4.9g 5.0g R 56.9  7.0 694:54.61 ora_p006_orcl
```

(Quite the TIME+ column there, huh!)

### Summary

In this post I've been a bit light on the technicals of PX, but that is mostly because 1) this is a fundamentals post and 2) there is a ton of more detail in the referenced documentation and I really don't feel like republishing what already exists. Bottom line, Oracle Parallel Execution is a must for scaling performance in your Oracle data warehouse.  Take the time to understand how to leverage it to maximize performance in your environment and feel free to start a discussion here if you have questions. 

### References

- [Concepts: Parallel Execution](http://download.oracle.com/docs/cd/E11882_01/server.112/e10713/process.htm#CNCPT220)
- [VLDB and Partitioning Guide: Using Parallel Execution ](http://download.oracle.com/docs/cd/E11882_01/server.112/e10837/parallel.htm)
- [Parallelism and Scalability for Data Warehousing](http://www.oracle.com/technetwork/database/focus-areas/bi-datawarehousing/dbbi-tech-info-sca-090608.html)
- [Oracle Database Parallel Execution Fundamentals in Oracle 11g Release 2](http://www.oracle.com/technetwork/database/focus-areas/bi-datawarehousing/twp-parallel-execution-fundamentals-133639.pdf)
- [Parallel Execution and Workload Management](http://www.oracle.com/technetwork/database/focus-areas/bi-datawarehousing/twp-bidw-parallel-execution-130766.pdf)
