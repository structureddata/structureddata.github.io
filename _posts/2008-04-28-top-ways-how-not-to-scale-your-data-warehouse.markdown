---
author: Greg Rahn
comments: true
date: 2008-04-28T08:00:47.000Z
layout: post
slug: top-ways-how-not-to-scale-your-data-warehouse
title: Top Ways How Not To Scale Your Data Warehouse
wp_id: 63
wp_categories:
  - Data Warehousing
  - Oracle
  - Performance
  - VLDB
wp_tags:
  - data warehouse fundamentals
  - data warehouse performance
  - optimal design decisions
  - VLDB
---

Working in the Real-World Performance Group at Oracle has allowed me to see quite a few customers' data warehouses.  Unfortunately some customers find their data warehouse suffering from performance problems, not because there is a platform issue, but often because the features are not used or are not used correctly.  I thought I'd put together a list of the most common problems but present them in a facetious manner.  The following is meant to be sarcastic and read with a bit of humor.  Consider it the "Comedy of Errors" data warehouse edition.

### Add An Index To Fix Each Slow Query

If you think the solution for slow queries in a data warehouse is to add indexes, you are probably mistaken.  Not only is index access likely the most inefficient way to access lots of rows, the more indexes that are on a table, the longer it takes to load data into that table, even if you build them after the data is loaded; not to mention the extra space that is required for those indexes.

### Do Not Use Parallel Operations

There is a reason that row-by-row processing is synonymous with slow-by-slow.  It does not scale.   If you want to make sure you will have no chance to scale your ETL/ELT, use PL/SQL cursor for loops and process the data serially.

Parallel query is one of the best ways to linearly reduce query response times so not using it would surely help you not scale your data warehouse.  Why would one want to solve a few queries in a short amount of time by leveraging a large amount of hardware resources with many parallel processes when you can run many serial queries each using a single process?  After all, you would not want to make your CPUs and disks too busy, as they might get tired.

### Do Not Use Partitioning

Not effectively using partitioning is probably the best way not to scale your data warehouse.  Without leveraging partition elimination in queries, is is pretty much a guarantee that the more data you add to your tables, the longer your queries will run.  Give yourself enough time and data, and you will surely have the slowest data warehouse on the planet, if not the most inefficient.

### Do Not Use Compression

Using compression would not only reduce the disk space required to store data, it also would reduce the amount of I/O bandwidth to bring data back to the host.  Given that most database servers have infinite storage capacity as well as infinite I/O bandwidth, compression would not yield much, if any benefit.  Why do less work when you can do more?

Besides, using compression makes the load take longer, right?  Given that the data is loaded once and queried thousands (or more) times, it would make sense to optimize for loading and not queries, no?

### Do Not Use Analytic SQL 

Why would anyone want to use analytic SQL when they can write simpler SQL that performs slower without that functionality.  After all, isn't it better to access the data multiple times versus a single pass?  The more times the data is accessed, the more likely it is to be in cache, correct?

### Do Not Use Materialized Views Or Aggregates

Why use a "work smarter, not harder" mentality when you can just brute force it.  After all, we are manly men and will not be shown up by brains and elegance.  We'd rather add up every row from the point of sale table for year end report versus adding up the monthly aggregates.  Disk space is cheap and performance is expensive, so perhaps if enough space is saved, it will add up, right?

### Do Not Store Data In Its Most Usable Format

Storing data in a uniform case (all upper or all lower) would make the data too clean and usable.  It's much more efficient to change the data with an upper() or lower() function each and every time the data is queried versus changing it once when it is loaded.  And while we are at it, let's store dates as strings and convert them every time as well.  Since there is idle CPU from running serial queries, might as well put it to good use changing the case of text and turning strings into dates, no?  Why store that GL segment number that everyone queries on in its own column when the users can just use a substring() function to find it.  After all, storing redundant data that would make queries perform better is not the primary objective, it's saving those bytes per row that is critical.

### Do Not Leverage Good Design

A data warehouse model is just an OLTP model with much more historical data and a few extra tables for reports, right?  One of the best ways to tank your data warehouse's performance is to design and manage it like it was a large OLTP database.  Fundamentally OLTP and data warehousing are completely different and have very little in common, but they can't be that different, can they?

Even though most BI tools work best when there is well designed model, it is possible to just put a layer of performance killing views in the database to make it look like a well designed dimensional model.  This way the ETL can stay simple, the users do not have to write complicated SQL and the BI tools will work (slowly).  Why take the time to design a good data model when you can emulate one at one tenth (or less) the scalability.

### Consume Excessive Time And Resources Gathering Statistics

Another great way to consume time and compute resources is gathering statistics on data that has not changed or has not significantly changed.  If you are regathering statistics on data that has not changed, you should probably consider that Albert Einstein once said "The definition of insanity is doing the same thing over and over again and expecting different results".

### Put The Data Warehouse On A Shared Disk Array

Given that a data warehouse generally requires significant I/O bandwidth and often times use significant disk and compute resources, it would probably be a good idea to share it with other systems.  This way the data warehouse (as well as the other applications) will not only have unpredictable performance, but the warehouse will have a scape goat for one to blame when there are issues.  Last time I checked, none of the data warehouse appliances or MPP data warehouse databases shared storage with anyone, so maybe they are missing something?
