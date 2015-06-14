---
author: Greg Rahn
comments: true
date: 2009-04-01T09:00:37.000Z
layout: post
slug: intel-nehalem-ep-xeon-5500-series-processors-makes-databases-go-2x-faster
title: Intel Nehalem-EP Xeon 5500 Series Processors Makes Databases Go 2X Faster
wp_id: 476
wp_categories:
  - Data Warehousing
  - Oracle
  - Performance
wp_tags:
  - Nehalem-EP Xeon 5500 Intel Oracle Benchmarks
---

As a database performance engineer there are certain things that get me really excited.  One of them is hardware.  Not just any hardware, but the latest, greatest, bleeding edge stuff.  It is especially exciting when the latest generation of CPUs are twice as fast as the previous generation, and those being no slouch.  This is how Intel's new [Nehalem-EP Xeon 5500 series processors](http://www.intel.com/technology/architecture-silicon/next-gen/) are shaping up.

The [big launch](http://www.intel.com/pressroom/archive/releases/20090330corp_sm.htm) was on March 30th so in the past few days all the benchmark reports and blog posts have been   rolling in.  Here are a few that I think are worth highlighting:

The [SQL Server Performance Blog reports](http://blogs.msdn.com/sqlperf/archive/2009/03/31/great-new-sql-server-performance-on-intel-s-xeon-5500-series-aka-nehalem-ep.aspx):

> Pat Gelsinger did a side-by-side performance demo which launched an SSRS report, running reporting queries against a 1.5 TB SSAS OLAP cube, built using a Microsoft adCenter data set. The demo showed how **Nehalem-EP is 2X faster than a Xeon 5400 on the same workload, with the same DRAM and I/O configuration**. Not too shabby, **but we've seen even faster results (~3-4X faster) on workloads which are more memory bandwidth-intensive, like data warehousing** or in-memory OLAP workloads.

Intel's [Dave Hill](http://communities.intel.com/people/dave_hill) over at the [The Server Room Blog writes](http://communities.intel.com/openport/community/openportit/server/blog/2009/03/30/nehalem-the-new-standard-for-energy-efficient-performance):

> As of March 30, 2009, Intel based 2 socket Xeon® 5500 series servers set at least 30 world performance records across a wide range of benchmarks that cover virtually every application type on the market. **The performance results, just by themselves, are utterly amazing, and in general they are greater than 2x the Intel® Xeon® 5400 series processors (Harpertown)**.

There are numerous other benchmarks listed over at the [Intel® Xeon® Processor Performance summary page](http://www.intel.com/performance/server/xeon/summary.htm). Check them out.  You should be nothing less than amazed.  It surely is a great time to be using commodity hardware and if you are not, perhaps you should be!  And for those database vendors who are using proprietary hardware like [FPGAs](http://en.wikipedia.org/wiki/Fpga), well, I guess you are wishing that Intel's Nehalem-EP processors are an [April Fools'](http://en.wikipedia.org/wiki/April_Fools%27_Day) joke, but you would be wrong.
