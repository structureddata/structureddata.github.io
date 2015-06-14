---
author: Greg Rahn
comments: false
date: 2009-06-03
layout: post
slug: oracle-and-hp-take-back-1-spot-for-1tb-tpc-h-benchmark
title: 'Oracle And HP Take Back #1 Spot For 1TB TPC-H Benchmark'
wp_id: 556
wp_categories:
  - Data Warehousing
  - Exadata
  - Oracle
  - Performance
wp_tags:
  - benchmarks
  - Exadata
  - HP
  - Oracle
  - TPC-H
---

[Oracle](http://oracle.com) and [HP](http://hp.com) have taken back the #1 spot by setting a new performance record in the 1TB TPC-H benchmark.  The HP/Oracle result puts the [Oracle database](http://www.oracle.com/database/) ahead of both the Exasol (currently #2 & #3) and ParAccel (currently #4) results in the race for performance at the 1TB scale factor and places Oracle in the >1 million queries per hour (QphH) club, which is no small achievement.  Compared to the next best result from HP/Oracle (currently #5), this result has over 9X the query throughput (1,166,976 QphH vs. 123,323 QphH) at around 1/4 the cost (5.42 USD vs. 20.54 USD) demonstrating significantly more performance for the money.

Some of the interesting bits from the hardware side:

- 4 HP BladeSystem c7000 Enclosures
- 64 HP ProLiant BL460c Servers
- 128 Quad-Core Intel Xeon X5450 "Harpertown" Processors (512 cores)
- 2TB Total System Memory (RAM)
- 6 [HP Oracle Exadata Storage Servers](http://www.oracle.com/database/exadata.html)

As you can see, this was a 64 node Oracle Real Application Cluster (RAC), each node having 2 processors (8 cores).  This is also the first TPC-H benchmark from Oracle that used Exadata as the storage platform.

Congratulation to the HP/Oracle team on the great accomplishment!

![Transaction Processing Performance Council_1244094205417.png](/assets/transaction-processing-performance-council-1244094205417.png)
