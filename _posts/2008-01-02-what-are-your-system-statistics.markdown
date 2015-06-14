---
author: Greg Rahn
comments: true
date: 2008-01-02T23:00:55.000Z
layout: post
slug: what-are-your-system-statistics
title: What Are Your System Statistics?
wp_id: 47
wp_categories:
  - 10gR2
  - 11gR1
  - Execution Plans
  - Optimizer
  - Oracle
  - Performance
  - SQL Tuning
  - Statistics
wp_tags:
  - aux_stats$
  - Oracle
  - system statistics
---

I've been working on a few test cases and I'm in search of some real-world data.  If your **production ** Oracle database uses system statistics, either [Workload Statistics](http://download.oracle.com/docs/cd/B19306_01/server.102/b14211/stats.htm#CIHIEIIA) or [Noworkload Statistics](http://download.oracle.com/docs/cd/B19306_01/server.102/b14211/stats.htm#CIHGHDFG), and you are willing to share them, please post a comment with the output from the following two queries:

```
select version from v$instance;
select pname, pval1 from sys.aux_stats$ where sname = 'SYSSTATS_MAIN';
```

For example, my noworkload system statistics look like this:

```
SQL> select version from v$instance;

VERSION
-----------------
11.1.0.6.0

SQL> select pname, pval1 from sys.aux_stats$ where sname = 'SYSSTATS_MAIN';

PNAME                               PVAL1
------------------------------ ----------
CPUSPEED
CPUSPEEDNW                        726.951
IOSEEKTIM                           4.683
IOTFRSPEED                       36625.24
MAXTHR
MBRC
MREADTIM
SLAVETHR
SREADTIM
```

To help with fixed width formatting (pretty printing), please surround your results in the comment text box with a pre tag like such:
`blah blah blah`


Thanks for participating!

Quick link to [10.2 System Statistics Documentation](http://download.oracle.com/docs/cd/B19306_01/server.102/b14211/stats.htm#i41496) for those unfamiliar with it.
