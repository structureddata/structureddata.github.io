---
author: Greg Rahn
comments: true
date: 2007-09-17T19:30:27.000Z
layout: post
slug: oracle-11g-enhancements-to-dbms_stats
title: 'Oracle 11g: Enhancements to DBMS_STATS'
wp_id: 25
wp_categories:
  - 10gR2
  - 11gR1
  - Data Warehousing
  - Optimizer
  - Oracle
  - Performance
  - Statistics
---
Many of you are aware of the [Oracle 11g Database New Features](http://download.oracle.com/docs/cd/B28359_01/server.111/b28279/chapter1.htm#NEWFTCH1) and while some may be generally interested in new features, one area that I focus on is new features that yield gains in performance. Some of these features can be found in the [General Server Performance](http://download.oracle.com/docs/cd/B28359_01/server.111/b28279/chapter1.htm#OBJECTIVENO04556) section of the [Oracle 11g Database New Features](http://download.oracle.com/docs/cd/B28359_01/server.111/b28279/chapter1.htm#NEWFTCH1) documentation. There is one area (for now...) that didn't make this list but I feel is worth mentioning - performance enhancements made to `DBMS_STATS`.

# The Necessity of Representative Statistics

Representative statistics are the foundation that the Optimizer relies on to make the best decisions when choosing execution plans. One [recent blog post](http://www.seiler.us/2007/08/dr-statslove-or-how-i-learned-to-stop.html) from Don Seiler, with the help of Wolfgang Breitling, is a prefect real-world case. This blog post dealt with out-of-range values, but one other case that often causes headaches is data skew. In the [Real-World Performance Roundtable, Part II session](http://structureddata.org/presentations/) at OracleWorld 2006, I discussed a basic stats gathering strategy that dealt with the exception case of data skew. When using the `DBMS_STATS` default of `DBMS_STATS.AUTO_SAMPLE_SIZE` in 10g and 9i, the NDV (Number of Distinct Values) may be statistically inaccurate when there is significant data skew. In order to deal with this exception, a fixed percentage of data that yields statistically representative NDV counts should be chosen. 

## 11g DBMS_STATS

In 11g there have been some enhancements made to the `DBMS_STATS` package. Overall the `GATHER_*` processes run faster but what stands out to me is the speed and accuracy that `DBMS_STATS.AUTO_SAMPLE_SIZE` now gives. As a performance person, I often times make reference to letting the numbers tell the story, so lets dive into a comparison between 10.2.0.3 and 11.1.0.5. I've chosen the same data set that I used in the "Refining the Stats" section of [Real-World Performance Roundtable, Part II session](http://structureddata.org/presentations/). Stats were serially gathered with `ESTIMATE_PERCENT` of 10%, 100%, and `DBMS_STATS.AUTO_SAMPLE_SIZE`.

**10.2.0.3**

run# | AUTO_SAMPLE_SIZE | 10% | 100%
--- | --- | --- | ---  
1 | 00:07:53.97 | 00:04:18.87 | 00:09:22.15
2 | 00:09:06.09 | 00:04:18.95 | 00:09:13.28
3 | 00:07:46.23 | 00:03:52.50 | 00:09:18.11
4 | 00:07:55.43 | 00:04:02.94 | 00:09:20.54
5 | 00:09:43.30 | 00:03:49.96 | 00:09:16.38

**11.1.0.5**

run# | AUTO_SAMPLE_SIZE | 10% | 100%
--- | --- | --- | ---  
1 | 00:02:39.31 | 00:02:38.55 | 00:07:37.83
2 | 00:02:21.86 | 00:02:31.56 | 00:08:24.10
3 | 00:02:38.11 | 00:02:49.49 | 00:07:38.25
4 | 00:02:26.60 | 00:02:27.75 | 00:07:42.25
5 | 00:02:29.95 | 00:02:29.45 | 00:07:42.49


# 11g DBMS_STATS Observations

As you can see by the numbers, 11g pulls a win in each of the three `GATHER_TABLE_STATS` calls. Take note of the `AUTO_SAMPLE_SIZE` timings. The 11g `AUTO_SAMPLE_SIZE` gather takes the same time as the 11g 10% sample. Not bad! 

## NDV Accuracy

We've seen that the 11g gather stats is overall faster and that the 11g `AUTO_SAMPLE_SIZE` shows a significant improvement in speed compared to 10.2.0.3 `AUTO_SAMPLE_SIZE` for this table, but how do the NDV calculations compare? Again, let's look at the numbers. I've queried `USER_TAB_COL_STATISTICS` to get the NDV and `SAMPLE_SIZE` for our skewed data set.

### 10.2.0.3

```
ESTIMATE_PERCENT => 10
COLUMN_NAME     NUM_DISTINCT  NUM_NULLS SAMPLE_SIZE
--------------- ------------ ---------- -----------
C1                     31464          0     2148910
C2                    608544          0     2148910
C3                    359424          0     2148910

ESTIMATE_PERCENT => 100%
COLUMN_NAME     NUM_DISTINCT  NUM_NULLS SAMPLE_SIZE
--------------- ------------ ---------- -----------
C1                     60351          0    21456269
C2                   1289760          0    21456269
C3                    777942          0    21456269

ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE
COLUMN_NAME     NUM_DISTINCT  NUM_NULLS SAMPLE_SIZE
--------------- ------------ ---------- -----------
C1                      1787          0        5823
C2                    367075          0      576909
C3                     52464          0       57431
```

### 11.1.0.5

```
ESTIMATE_PERCENT => 10
COLUMN_NAME     NUM_DISTINCT  NUM_NULLS SAMPLE_SIZE
--------------- ------------ ---------- -----------
C1                     31320          0     2147593
C2                    608814          0     2147593
C3                    359365          0     2147593

ESTIMATE_PERCENT => 100
COLUMN_NAME     NUM_DISTINCT  NUM_NULLS SAMPLE_SIZE
--------------- ------------ ---------- -----------
C1                     60351          0    21456269
C2                   1289760          0    21456269
C3                    777942          0    21456269

ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE
COLUMN_NAME     NUM_DISTINCT  NUM_NULLS SAMPLE_SIZE
--------------- ------------ ---------- -----------
C1                     59852          0    21456269
C2                   1270912          0    21456269
C3                    768384          0    21456269
```

As expected, the 100% samples are identical and the 10% samples are statistically equivalent. One interesting data point is that the `SAMPLE_SIZE` for the 11g `AUTO_SAMPLE_SIZE` run shows the exact `SAMPLE_SIZE` as the 100% gather - the total number of rows in the table. Also note that the NDV counts for the 11g `AUTO_SAMPLE_SIZE` gather are statistically equivalent to the 100% sample. What does this mean? It means that the 11g `AUTO_SAMPLE_SIZE` had been enhanced to provide nearly 100% sample accuracy, even on skewed data sets.

# Summary

Overall the 11g `DBMS_STATS` has been enhanced to gather stats in less time, but in my opinion the significant enhancement is to `AUTO_SAMPLE_SIZE` which yields near 100% sample accuracy in 10% sample time. As [the documentation](http://download.oracle.com/docs/cd/B28359_01/server.111/b28274/stats.htm#sthref1152) says:

> ...Oracle recommends setting the `ESTIMATE_PERCENT` parameter of the `DBMS_STATS` gathering procedures to `DBMS_STATS.AUTO_SAMPLE_SIZE` to maximize performance gains while achieving necessary statistical accuracy.

I couldn't agree with the documentation more. If you wish to know more about how the new `DBMS_STATS.AUTO_SAMPLE_SIZE` works, see section 3 of [_Efficient and scalable statistics gathering for large databases in Oracle 11g_](http://portal.acm.org/citation.cfm?id=1376616.1376721).
