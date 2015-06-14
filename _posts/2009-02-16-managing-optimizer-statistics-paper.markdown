---
author: Greg Rahn
comments: true
date: 2009-02-16T09:00:23.000Z
layout: post
slug: managing-optimizer-statistics-paper
title: Managing Optimizer Statistics Paper
wp_id: 380
wp_categories:
  - Execution Plans
  - Optimizer
  - Statistics
wp_tags:
  - correlated columns
  - dynamic sampling
---

Over the past couple days I've been reading through the recent paper by [Karen Morton](http://karenmorton.blogspot.com) entitled "[Managing Statistics for Optimal Query Performance](http://karenmorton.blogspot.com/2009/02/new-paper-and-cj-date-advert.html)".  In this paper Karen goes over many of the topics I have discussed as well (and a few that I have not) in the following blog posts:

- [Troubleshooting Bad Execution Plans](/2007/11/21/troubleshooting-bad-execution-plans/)
- [There Is No Time Like 'NOW%' To Use Dynamic Sampling](/2008/03/05/there-is-no-time-like-now-to-use-dynamic-sampling/)
- [Choosing An Optimal Stats Gathering Strategy](/2008/03/26/choosing-an-optimal-stats-gathering-strategy/)
- [DBMS_STATS, METHOD_OPT and FOR ALL INDEXED COLUMNS](/2008/10/14/dbms_stats-method_opt-and-for-all-indexed-columns/)

Overall I think Karen does a good job discussing the key issues related to object statistics and has examples to assist in understanding where and why issues can arise.  I'm also a fan of works that do not project an answer, but rather provide information, how to use that information, use working examples, and ultimately leaves the reader with the task of how to best apply the new found knowledge to their environment.  I would recommend to all to give it a read.

### Comments On Dynamic Sampling

In section 5.1 on page 22 Karen discusses using dynamic sampling, of particular interest she has a table of statistics from Robyn Sands that compares two different runs of some application jobs both using `optimizer_dynamic_sampling=4`.  One uses stats collected with a 100% sample.  The other uses no static stats at all, only using dynamic sampling.  The data that Robyn has captured looks interesting, but I'm not exactly sure how to interpret all of it (there are a lot of numbers in that chart) and only two sentences that speak to the data.  I think I understand what message behind chart but I think it would be easier to see the median along with the average so that one could clearly see there is a large range of values, thus indicating there are numbers far away from the median indicating some vast difference.  This type of comparison (before change/after change) is exactly what the Oracle Database 11g [SQL Performance Analyzer](http://www.oracle.com/pls/db111/search?remark=quick_search&word=sql+performance+analyzer&partno=) ([SPA](http://www.oracle.com/technology/products/manageability/database/pdf/ow07/spa_white_paper_ow07.pdf)) was designed for.  One of the reasons I think SQL Performance Analyzer is a great tool for controlled execution and comparison of SQL statements is that not only collects all the execution metrics, but also it captures the execution plan.  Looking at the data from Robyn leaves me with the question: For the SQL statements executed, which ones had a plan change, and was that plan change for the better or for worse?  The last comment I would make is that while relying 100% on dynamic sampling (having no object statistics) is an interesting data point, I would not recommend this for a production database.  Dynamic sampling was designed to augment static statistics and to provide some statistics to the query optimizer in the cases where none exist and only guesses (or selectivity constants) would otherwise be used.  The main logic behind this recommendation is that dynamic sampling does not provide all metadata that static statistics provide, it only provides a subset.  While this subset of metadata may be enough to get the equivalent plan at times, frequently it is not.

### Remember The Chain of Events

Karen mentions (page 5) something that was in the Oracle OpenWorld 2008 session "[Real-World Database Performance Techniques and Methods](/presentations/)" (slide 29):

![Slide29.jpg](/assets/slide29.jpg)

Having a good understanding of this chain of events should help you in getting to the root cause of poor execution plans.  The key takeaway is to recognize that without representative statistics, the optimizer has very little chance to choose the best execution plan, so give it the best chance you can.

### Additional Resources

If you have not looked through the slides from [Real-World Database Performance Techniques and Methods](/presentations/) I might suggest you do.  There is some great information based on the Real-World Performance Group's experience that centers around this topic.   Especially note the sections:

- Optimizer Exposé (slide 7)
- Managing Statistics on Partitioned Tables (slide 34)

Hopefully you find the information in those slides useful.
