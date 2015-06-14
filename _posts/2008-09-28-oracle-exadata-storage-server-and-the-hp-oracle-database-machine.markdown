---
author: Greg Rahn
comments: true
date: 2008-09-28T08:00:16.000Z
layout: post
slug: oracle-exadata-storage-server-and-the-hp-oracle-database-machine
title: Oracle Exadata Storage Server and the HP Oracle Database Machine
wp_id: 133
wp_categories:
  - Exadata
  - Oracle
wp_tags:
  - HP Oracle Database Machine
  - Oracle Exadata
  - Oracle Exadata Storage Server
---

If you haven't been under a rock you know that Larry Ellison announced the [Oracle Exadata Storage Server](http://www.oracle.com/solutions/business_intelligence/exadata.html) and the [HP Oracle Database Machine](http://www.oracle.com/solutions/business_intelligence/database-machine.html) at [Oracle OpenWorld 2008](http://www.oracle.com/openworld/2008/index.html).  There seems to be quite a bit of interest and excitement about the product and I for one will say that I am _extremely_ excited about it especially after having used it.  If you were an OOW attendee, hopefully you were able to see the HP Oracle Database Machine live demo that was in the Moscone North lobby.  [Kevin Closson](http://kevinclosson.wordpress.com) and I were both working the live demo Thursday morning and  [Doug Burns](http://oracledoug.com) snapped a [few photos of Kevin and I](http://oracledoug.com/serendipity/index.php?/archives/1443-Day-4-Grumpy-Old-Man.html) doing the demo.

### HP Oracle Database Machine Demos

In order to demonstrate Oracle Exadata, we had an HP Oracle Database Machine set up with some live demos.  This Database Machine was split into two parts, the first had two Oracle database servers and two Oracle Exadata servers, the second had six Oracle database servers and 12 Oracle Exadata servers.  A table scan query was started on the two Oracle Exadata servers config.  The same query was then started on the 12 Oracle Exadata servers config.  The scan rates were displayed on the screen and one could see that each Exadata cell was scanning at a rate around 1GB/s for a total aggregate of around 14GB/s.  Not too bad for a single 42U rack of gear.  This demo also showed that the table scan time was linear with the number of Exadata cells: 10 seconds vs. 60 seconds.  With six times the number of Exadata cells, the table scan time was cut by 6.

The second live demo we did was to execute query consisting of a four table join (PRODUCTS, STORES, ORDERS, ORDER_ITEMS) with some data that was based off one of the trial customers.  The query was to find how many items were sold yesterday in four southwestern states of which the item name contained the string "chili sauce".  The ORDER_ITEMS table contained just under 2 billion rows for that day and the ORDERS table contained 130 million rows for the day.  This query's execution time was less than 20 seconds.  The execution plan for this query was all table scans - no indexes, etc were used.

### When One HP Oracle Database Machine Is Not Enough

As a demonstration of the linear scalability of Oracle Exadata, a configuration of six (6) HP Oracle Database Machines for a total of 84 Exadata cells was assembled.  14 days worth of POS (point of sale) data onto one Database Machine and executed a query to full table scan the entire 14 days.  Another 14 days of data were loaded and a second Database Machine was added to the configuration.  The query was run again, now against 28 days across two Database Machines.  This process was repeated, loading 14 more days of data and adding another Database Machine until 84 days were loaded across six Database Machines.  As expected, all six executions of the query were nearly identical in execution time demonstrating the scalability of the product.  The amazing bit about this all was with six Database Machines and 84 days of data (around 163 billion rows), the physical I/O scan rate was **over 74 GB/s (266.4 TB/hour) sustained**.  To put that in perspective, it **equates to scanning 1 TB of _uncompressed_ data in just 13.5 seconds**.  In this case, Oracle's compression was used so the **time to scan 1 TB of user data was just over 3 seconds**.  Now that is extreme performance!!!

As I'm getting ready to post this, I see [Kevin has beat me to it](http://kevinclosson.wordpress.com/2008/09/27/hp-oracle-database-machine-a-thing-of-beauty-capable-of-real-throughput/).  Man, that guy is an extreme blogging machine.

### Initial Customer Experiences

Several Oracle customers had a 1/2 HP Oracle Database Machine (see Kevin's comments below) to do testing with **their data and their workloads**.  These are the ones that were highlighted in Larry's keynote.

**[M-Tel](http://mtel.bg)**
- Currently runs on two IBM P570s with EMC CX-30 storage
- 4.5TB of Call Data Records
- Exadata speedup: 10x to 72x (average 28x)
- "Every query was faster on Exadata compared to our current systems.  The smallest performance improvement was 10x and the biggest one was 72x."

**[LGR Telecommunications](http://www.lgrtelecoms.com)**
- Currently runs on HP Superdome and XP24000 storage
- 220TB of Call Data Records
- "Call Data Records queries that used to run over 30 minutes now complete in under 1 minute.  That's extreme performance."

**[CME Group](http://cmegroup.com)**
- "Oracle Exadata outperforms anything we've tested to date by 10 to 15 times.  This product flat out screams."

**[Giant Eagle](http://www.gianteagle.com)**
- Currently runs on IBM P570 (13 CPUs) and EMC CLARiiON and DMX storage
- 5TB of retail data
- Exadata speedup: 3x to 50x (average 16x)
