---
author: Greg Rahn
comments: true
date: 2008-12-12
layout: post
slug: the-best-benchmarketing-ive-seen-yet-measure-bi-queries-in-miliseconds
title: "The Best Benchmarketing I've Seen Yet: Measure BI Queries In Milliseconds"
wp_id: 332
wp_categories:
  - Data Warehousing
  - Oracle
  - Performance
wp_tags:
  - column store
  - HP Oracle Database Machine
  - Performance
  - row store
  - Vertica
---

After posting about how ridiculous some of the [benchmarketing claims](http://structureddata.org/2008/12/12/database-customer-benchmarketing-reports/) that database vendors are making, Dave Menninger, VP of Marketing & Product Management at Vertica [posted a comment](http://structureddata.org/2008/12/12/database-customer-benchmarketing-reports/#comment-5401) that one of their customers reported a 40,400x gain in one query (this of course is after I openly joked about the 16,200x Vertica claim).  So I made my way over to check out this claim, and sure enough, someone reported this.  Here is the table presented in the webcast:

![hMetrix_Vertica.png](/assets/hmetrix-vertica1.png)

To this database performance engineer, this yet another unimpressive performance claim, but rather a **very** creative use of numbers, or maybe better put, a [good case of bad math](http://scienceblogs.com/goodmath/).  Or better yet, big fun with small numbers.  Honestly, measuring a BI query response time in milliseconds?!?!  I don't even know if OLTP database users measure their query response time in milliseconds.  I simply can't stop laughing at the fact that there needs to be precision below 1 second.  Obviously BI users could not possibly tell that their query ran in less than 1 second because the network latency would mask this.   Not only that, it seems there were 154 queries to choose from and the Vertica marketing crew chose to mention this one.  Brilliant I say.  So yes Dave, this is even more ludicrous than the 16,200x claim.  At best it is a 202x gain.  You won't get credit from me (and probably others) for fractional seconds, but thanks for mentioning it.  It was a good chuckle.  By the way, why add two extra places of precision for this query and not all the others?

I think it is also worth mentioning that the data set size for this case is 84GB (raw) and 10.5GB in the Vertica DB (8x compression).  Given the server running the database has 32GB of RAM it easily classifies as an in-memory database, so response time should certainly be in the seconds.  I don't know about you, but performance claims on a database in which the uncompressed data fits on an [Apple iPod](http://www.apple.com/ipodclassic/) don't excite me.

Dave Menninger also mentions:

> One other piece of information in an effort of full (or at least more) disclosure is the following blog post that breaks down the orders of magnitude differences between row stores and column stores to their constituent parts.
> [Debunking Yet Another Myth: Column-Stores As A Storage-Layer Only Optimization](http://www.databasecolumn.com/2008/12/debunking-yet-another-myth-col.html)


Column stores have been a topic of many research papers.  The one that has caught my attention most recently is the paper by [Allison Holloway](http://pages.cs.wisc.edu/~ahollowa/) and [David DeWitt](http://pages.cs.wisc.edu/~dewitt/) (Go Badgers!) entitled [Read-Optimized Databases, In Depth](http://pages.cs.wisc.edu/~ahollowa/paper377.pdf) and the VLDB 2008 presentation which has an alternate title of [Yet Another Row Store vs Column Store Paper](https://www.se.auckland.ac.nz/conferences/VLDB2008resources/presentations/papers/R39.ppt).  I might suggest that you give them a read.  Perhaps the crew at [The Database Column](http://www.databasecolumn.com/) will offer some comments on Allison and David's research.  I'm surprised that they haven't already.

Well, that's enough fun for a Friday.  Time to kick off some benchmark queries on my [HP Oracle Database Machine](http://www.oracle.com/solutions/business_intelligence/database-machine.html).
