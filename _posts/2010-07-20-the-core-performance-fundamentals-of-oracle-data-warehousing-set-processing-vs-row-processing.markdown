---
author: Greg Rahn
comments: true
date: 2010-07-20T09:00:38.000Z
layout: post
slug: the-core-performance-fundamentals-of-oracle-data-warehousing-set-processing-vs-row-processing
title: The Core Performance Fundamentals Of Oracle Data Warehousing – Set Processing vs Row Processing
wp_id: 939
wp_categories:
  - Data Warehousing
  - Exadata
  - Oracle
  - Performance
  - SQL Tuning
  - VLDB
wp_tags:
  - Exadata
  - Oracle Exadata
  - row processing
  - set processing
---

[back to [Introduction](/2009/12/14/the-core-performance-fundamentals-of-oracle-data-warehousing-introduction/)]

In over six years of doing data warehouse POCs and benchmarks for clients there is one area that I frequently see as problematic: "batch jobs".  Most of the time these "batch jobs" take the form of some [PL/SQL](http://www.oracle.com/technology/tech/pl_sql/index.html) procedures and packages that generally perform some data load, transformation, processing or something similar.  The reason these are so problematic is that developers have [hard-coded](http://en.wikipedia.org/wiki/Hard_coding) "slow" into them.  I'm generally certain these developers didn't know they had done this when they coded their PL/SQL, but none the less it happened.

### So How Did "Slow" Get Hard-Coded Into My PL/SQL?

Generally "slow" gets hard-coded into PL/SQL because the PL/SQL developer(s) took the business requirements and did a "literal translation" of each rule/requirement one at a time instead of looking at the "before picture" and the "after picture" and determining the most efficient way to make those data changes.  Many times this can surface as cursor based row-by-row processing, but it also can appear as PL/SQL just running a series of often poorly thought out SQL commands.

### Hard-Coded Slow Case Study

_The following is based on a true story. Only the names have been changed to protect the innocent._

Here is a pseudo code﻿ snippet based on a portion of some data processing I saw in a POC:

```
{truncate all intermediate tables}
insert into temp1 select * from t1 where create_date = yesterday;
insert into temp1 select * from t2 where create_date = yesterday﻿;
insert into temp1 select * from t3 where create_date = yesterday﻿;
insert into temp2 select * from temp1 where {some conditions};
insert into target_table select * from temp2;
for each of 20 columns
loop
  update target_table﻿ t
    set t.column_name =
      (select column_name
       from t4
       where t.id=t4.id )
    where i.column_name is null;﻿
end loop
update target_table﻿﻿ t set {list of 50 columns} = select {50 columns} from t5 where t.id=t5.id;﻿
```

I'm going to stop there as any more of this will likely make you cry more than you already should be.

I almost hesitate to ask the question, but isn't it quite obvious what is broken about this processing?  Here's the major inefficiencies as I see them:

- What is the point of inserting all the data into `temp1`, only then to filter some of it out when `temp2` is populated.  If you haven't heard the phrase ["filter early"](http://carymillsap.blogspot.com/2010/05/filter-early.html) you have some homework to do.
- Why publish into the `target_table` and then perform 20 single column updates, followed by a single 50 column update?  Better question yet: Why perform _any_ bulk updates at all?  Bulk updates (and deletes) are simply evil - avoid them at all costs.

So, as with many clients that come in and do an Exadata Database Machine POC, they really weren't motivated to make any changes to their existing code, they just wanted to see how much performance the Exadata platform would give them.  Much to their happiness, this reduced their processing time from over 2.5 days (weekend job that started Friday PM but didn't finish by Monday AM) down to 10 hours, a savings of over 2 days (24 hours).  Now, it could fail and they would have time to re-run it before the business opened on Monday morning.  Heck, I guess if I got back 24 hours out of 38 I'd be excited too, if I were not a database performance engineer who knew there was _even more_ performance left on the table, waiting to be exploited.

Feeling unsatisfied, I took it upon myself to demonstrate the significant payback that re-engineering can yield on the Exadata platform and I coded up an entirely new set-based data flow in just a handful of SQL statements (no PL/SQL).  The result: processing an entire week's worth of data (several 100s of millions of rows) now took just 12 minutes.  That's right -- 7 days worth of events scrubbed, transformed, enriched﻿﻿ and published in just 12 minutes.

When I gently broke the news to this client that it was possible to load the week's events in just 12 minutes they were quite excited (to say the least).  In fact, one person even said (a bit out of turn), "well, that would mean that a single day's events could be loaded in just a couple minutes and that would give a new level of freshness to the data which would allow the business to make faster, better decisions due to the timeliness of the data."  My response: "BINGO!"  This client now had the epiphany﻿ of what is now possible with Exadata where previously it was impossible.

### It's Not a Need, It's a Want

I'm not going to give away my database engineer hat for a product marketing hat just yet (or probably ever), but this is the reality that exists.  IT shops started with small data sets and use small data set programming logic on their data, and that worked for some time.  The reason: because inefficient processing on a small data set is only a little inefficient, but the same processing logic on a big data set is very inefficient.  This is why I have said before: In oder to fully exploit the Oracle Exadata platform (or any current day platform) some re-engineering may be required. Do not be mistaken -- I am not saying you _**need**_ to re-engineer your applications for Exadata.  I am saying you will _**want**_ to re-engineer your applications for Exadata﻿ as those applications simply were not designed to leverage the massively parallel processing that Exadata allows one to do.  It's time to base design decisions based on today's technology, not what was available when your application was designed.  Fast forward to now.
