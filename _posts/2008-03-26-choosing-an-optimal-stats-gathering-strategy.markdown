---
author: Greg Rahn
comments: true
date: 2008-03-26T08:00:38.000Z
layout: post
slug: choosing-an-optimal-stats-gathering-strategy
title: Choosing An Optimal Stats Gathering Strategy
wp_id: 62
wp_categories:
  - 10gR2
  - Execution Plans
  - Optimizer
  - Oracle
  - Statistics
  - Troubleshooting
wp_tags:
  - auto_sample_size
  - bind peeking
  - DBMS_STATS
  - histograms
  - out-of-range predicates
  - stats gathering strategy
---

Recently the [Oracle Optimizer Development Team](http://optimizermagic.blogspot.com/) put out a White Paper entitled _[Upgrading from Oracle Database 9i to 10g: What to expect from the Optimizer](http://www.oracle.com/technology/products/bi/db/10g/pdf/twp_bidw_optimizer_10gr2_0208.pdf)_.  This paper discusses the main differences between 9i and 10g in the subject area of the Optimizer and Statistics.   As [G.I. Joe](http://en.wikipedia.org/wiki/G.I._Joe) said, "Now we know! And knowing is half the battle." The other half of the battle is successfully applying that knowledge to the databases that you manage.  Statistics are input to the Oracle Optimizer and the foundation of good plans.  If the statistics supplied to the Oracle Optimizer are non-representative we can probably expect  [GIGO](http://en.wikipedia.org/wiki/Garbage_in,_garbage_out) (Garbage In, Garbage Out).  On the other hand, if the statistics are representative, chances quite good that the Oracle Optimizer will choose the optimal plan.  In this post I'd like to discuss my thoughts on how to choose an optimal stats gathering strategy.

### Suggested Readings

If you haven't done so already, I would first suggest reading the following:

- [10g Release 2: Managing Optimizer Statistics](http://download.oracle.com/docs/cd/B19306_01/server.102/b14211/stats.htm)
- [Oracle OpenWorld 2005: A Practical Approach to Optimizer Statistics in Oracle Database 10g](http://www.oracle.com/technology/deploy/performance/pdf/PS_S961_273961_106-1_FIN_v2.pdf)
- [Upgrading from Oracle Database 9i to 10g: What to expect from the Optimizer](http://www.oracle.com/technetwork/database/focus-areas/bi-datawarehousing/twp-bidw-optimizer-10gr2-0208-130973.pdf)
- [Upgrading from Oracle Database 10g to 11g: What to expect from the Optimizer](http://www.oracle.com/technetwork/database/focus-areas/bi-datawarehousing/twp-upgrading-10g-to-11g-what-to-ex-133707.pdf)

### Start With A Clean Slate

My first recommendation is to unset any Optimizer related parameters that exist in your init.ora, unless you have specific recommendations from the application vendor. This includes (but is not limited to):

- `optimizer_index_caching`
- `optimizer_index_cost_adj`
- `optimizer_mode`
- `db_file_multiblock_read_count`

In almost every case, the defaults for these parameters are more than acceptable.

The same goes for any events and undocumented/hidden/underscore parameters that are set. **Hidden parameters and events should only be used to temporarily work around bugs under the guidance and direction of Oracle Support and Development.**  Contrary to what you may find on the Internet via your favorite search engine, hidden parameters are not meant to be tuning mechanisms and are not a source of magic performance gains.  They are mechanisms that developers have instrumented into their code to debug problems and only those developers know and understand the full impact of changing hidden parameters.

### High Level Strategy

- **Start With the Defaults:** In most cases, the defaults for Optimizer parameters and `DBMS_STATS` are adequate.  If you are upgrading from 9i to 10g, do your homework and note the differences in the defaults.  Test them to see if they work well for your data and your execution plans.
- **Dealing With Suboptimal Execution Plans:** There may be cases of query plan regression.  It is very important to be diligent about finding root cause.  Often times many plan regressions surface from the same root cause.  This means if you can correctly diagnose and resolve the root cause, you have the potential to resolve many plan regressions.
- **Adjust Strategy to Cope with the Exceptions:** Once it is understood why the suboptimal plan was chosen, a resolution can be tested and implemented.

## Start With The Defaults

I can not stress enough how important it is to start with the defaults for Optimizer and `DBMS_STATS` parameters.  The Real-World Performance Group has dealt with numerous cases where customers are not using the default values for Optimizer parameters and by simply setting them back to the default values performance **increases** .  If you are planning to regression test your system because you are upgrading your database, there is no better time to do a reset of these parameters.  It will also put you in a much better place to troubleshoot if you run into issues.  Give the software the best chance to do what it can for you.  Don't try and be too clever for your own good.

One of the most common problems I've seen is that customers have chosen a _magic_ fixed percentage for `ESTIMATE_PERCENT` in `DBMS_STATS`.  Why do I call it magic?  Because the customers had no systematic reasoning for the value they chose.

In the Real-World Performance Group Roundtable session at Oracle OpenWorld 2007 the topic of `DBMS_STATS` came up and I asked *"How many people are using `ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE`?"*  A handful of people raised their hands.  I then asked, *"For those of you who are using a fixed value for `ESTIMATE_PERCENT`, who can explain how they chose their number, other than just picking it out of the air."*  Not one person raised their hand.  Scary!  The moral of the story: You should have a documented reason (and test case) to deviate from the defaults.

## Dealing With Suboptimal Execution Plans

Probably the most common root cause (I'd say >90%) for suboptimal execution plans is poor cardinality estimates by the Optimizer.  Poor cardinality estimates are generally the result of non-representative statistics.  This means that the root cause of most Optimizer related issues are actually stats related, reaffirming how important it is to have representative stats.  For more details on troubleshooting poor cardinality estimates, I would suggest reading my post on [Troubleshooting Bad Execution Plans](/2007/11/21/troubleshooting-bad-execution-plans/).

In 10g, Automatic SQL Tuning was introduced via Enterprise Manager (which uses the package `DBMS_SQLTUNE`).  I would highly recommend that you evaluate this tool (if you have it licensed).  I've found that it can often come up with quite good suggestions and fixes.

Another option that is available to help get more accurate cardinality estimates is [dynamic sampling](http://download.oracle.com/docs/cd/B19306_01/server.102/b14211/stats.htm#i43032).  This is probably an underused option which can help with getting more accurate cardinality estimates when there is data correlation, etc.  Dynamic sampling is most appropriate for DSS and data warehouse databases, where queries run for minutes, not seconds.  See my post [There Is No Time Like '%NOW%' To Use Dynamic Sampling](/2008/03/05/there-is-no-time-like-now-to-use-dynamic-sampling/) for a real-world example.

## Adjust Strategy To Cope With The Exceptions

There are three scenarios that seem to be rather common:

- Non-representative NDV with skewed data
- Out-of-range predicates and partitioned tables
- Bind peeking when histograms exist

## Non-Representative NDV With Skewed Data

There are cases where the defaults for `DBMS_STATS` (`ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE`) may not yield representative NDV in 9i and 10g.  One specific case that I've seen repeatedly is when there is a large number of values and significant data skew.  In this case a fixed sample size that yields representative NDV should be chosen.  For a more in-depth review of this see my post on the new [11g DBMS_STATS.AUTO_SAMPLE_SIZE](/2007/09/17/oracle-11g-enhancements-to-dbms_stats/), it goes through an example of the 10g `AUTO_SAMPLE_SIZE` NDV/skew issue.

While having accurate NDV statistics is desirable, do not be come obsessed with having perfect NDV statistics.  The goal is to have the Optimizer choose the desired plan, not have perfect NDV.  Having more accurate NDV may not change the plan.  This is a case when less than perfect may be good enough.  Don't lose focus of the goal.

### Out-of-range Predicates And Partitioned Tables

Another case that frequently comes up is usually related to out-of-range predicates with partitioned tables that do not have representative stats.  [Don Seiler's](http://seilerwerks.wordpress.com) write-up of [his real-world case](http://seilerwerks.wordpress.com/2007/08/17/dr-statslove-or-how-i-learned-to-stop-guessing-and-love-the-10053-trace/) is a poster child for this exception.  If you are bulk loading data into a partitioned table, it is necessary that if statistics exist, they are representative.  This problem generally surfaces when statistics have been collected on an empty partition (so all stats are zeros) and now the partition has been bulk loaded.  There are a few options here:

- Stats are gathered immediately after the loading directly into the target table.
- Data is loaded into a staging table, stats are gathered, and the staging table is partition exchanged into the target table.
- Stats are cloned or copied (see [`DBMS_STATS.COPY_TABLE_STATS`](https://docs.oracle.com/cd/B28359_01/appdev.111/b28419/d_stats.htm#sthref8237) from a similar partition.
- There are no statistics and dynamic sampling will kick in (assuming it is set to the default of 2 or higher).

From what I have seen, this case generally shows up if the query plan has partition elimination to a single partition.  This is because when only one partitioned is accessed only partition stats are used, but when more than one partition is accessed, both the global/table stats and partition stats are used.

### Bind Peeking When Histograms Exist

The combination of these two seem to be a frequent cause of issue in 10g with OLTP systems.  In my opinion, these two features should not be used together (or used with complete understanding and extreme caution).  My reasoning for this is when histograms exist, execution plans can vary based on the filter predicates.  Well designed OLTP systems use bind variables for execution plan reuse.  On one hand plans can change, and on the other hand plans will be reused.  This seems like a complete conflict of interest, hence my position of one or the other.  Oh, and lets not overlook the fact that if you have a RAC database it's possible to have a different plan on each instance depending on what the first value peeked is.  Talk about a troubleshooting nightmare.

Unlike many, I think that disabling bind peeking **is not** the right answer.  This does not address the root cause, it attempts to curb the symptom.  If you are running an OLTP system, and you are using the nightly `GATHER_STATS_JOB` be mindful that it uses it's own set of parameters: it overrides most of the parameters. The doc says:

> When `GATHER AUTO` is specified, the only additional valid parameters are stattab, statid, objlist and statown; **all other parameter settings are ignored**.

It may be best to change the default value of the `METHOD_OPT` via [`DBMS_STATS.SET_PARAM`](https://docs.oracle.com/cd/B19306_01/server.102/b14211/stats.htm#sthref1068) to `'FOR ALL COLUMNS SIZE REPEAT'` and gather stats with your own job.  Why `REPEAT` and not `SIZE 1`?  You may find that a histogram is needed somewhere and using `SIZE 1` will remove it the next time stats are gathered.  Of course, the other option is to specify the value for `METHOD_OPT` in your gather stats script.

### Common Pitfalls And Problems

-  **Disabling The 10g `GATHER_STATS_JOB`:**  As many of you know in 10g the [`GATHER_STATS_JOB`](http://download.oracle.com/docs/cd/B19306_01/server.102/b14211/stats.htm#sthref1068) was introduced.  Since many customers have custom stats gathering scripts in place, many have chosen to disable this job.  Disabling the `GATHER_STATS_JOB` entirely is not recommended because it also gathers dictionary stats (SYS/SYSTEM schemas).  If you wish to collect your statistics manually, then you should change the value of `AUTOSTATS_TARGET` to `ORACLE` instead of `AUTO` (`DBMS_STATS.SET_PARAM('AUTOSTATS_TARGET','ORACLE')`).  This will keep the dictionary stats up to date and allow you to manually gather stats on your schemas as you have done so in 9i.
-  **Representative Statistics:** When troubleshooting bad execution plans it is important to evaluate if the statistics are representative.  Many times customers respond with "_I just gathered statsitics_" or "_The statistics are recent_".  Recently gathered statistics **does not** equate to representative statistics.  Albert Einstein once said "The definition of insanity is doing the same thing over and over again and expecting different results".  It applies here as well. 
-  **Too Much Time Spent On Stats Gathering:** Often when customers say their stats gathering is taking too long I ask to see their `DBMS_STATS` script.  Generally there are three reasons that stats gathering is taking too long:
	  -  **Stats are gathered with too fine of setting for `GRANULARITY`:**  It is usually unnecessary to gather subpartition stats for composite partitioned tables.  Don't spend time collecting stats that are not needed. Don't override the default for `GRANULARITY` unless you have a reason: the default probably is sufficient.
	  -  **Stats are gathered with unnecessarily large `ESTIMATE_PERCENT`:**  Use `DBMS_STATS.AUTO_SAMPLE_SIZE` to start with and adjust if necessary.  No need to sample 10% when 1% or less yields representative statistics.  Give `DBMS_STATS.AUTO_SAMPLE_SIZE` the chance to choose the best sample size. 
	  -  **Stats are gathered more frequently than required or on data that hasn't changed:** The `GATHER_STATS_JOB` uses `OPTIONS => 'GATHER AUTO'` so it only gathers statistics on objects with more than a 10% change **with a predefined set of options**.  If you are gathering statistics on tables/partitions that haven't changed, or haven't changed significantly, you may be spending time gathering unnecessary statistics.  For example, there is no need to gather partition stats on last months (or older) if the data in the partition is no longer volatile.
- **Not Understanding The Data:**  The answers are almost always in the data...skew, correlation, etc.  Many operational DBAs don't have an in-depth understanding of the data they are managing.  If this is the case, grab an engineer or analyst that is familiar with the data and work together.  Two smart people working on a problem is almost always better than one!
- **Do Not Mess With Optimizer Parameters:** If an execution plan is not choosing an index, understand why.  Use the tools available.  The [`GATHER_PLAN_STATISTICS`](/2007/11/21/troubleshooting-bad-execution-plans/) hint is a prefect place to start.  Fiddling with Optimizer parameters **is not** the solution.
