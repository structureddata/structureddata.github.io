---
author: Greg Rahn
comments: true
date: 2009-06-10T23:21:59.000Z
layout: post
slug: facebook-hive-a-petabyte-scale-data-warehouse-using-hadoop
title: 'Facebook: Hive - A Petabyte Scale Data Warehouse Using Hadoop'
wp_id: 584
wp_categories:
  - Data Warehousing
  - VLDB
wp_tags:
  - data warehouse
  - facebook
  - hive
  - MapReduce
  - petabyte scale
---

Today, June 10th, marks the  [Yahoo! Hadoop Summit '09](http://developer.yahoo.com/events/hadoopsummit09/) and the crew at Facebook have a writeup on the [Facebook Engineering page](http://www.facebook.com/note.php?note_id=89508453919#/notes.php?id=9445547199) entitled: [_Hive - A Petabyte Scale Data Warehouse Using Hadoop_](http://www.facebook.com/note.php?note_id=89508453919#/note.php?note_id=89508453919).

I found this an very interesting read given some of the Hadoop/MapReduce [comments from David J. DeWitt and Michael Stonebraker](http://www.databasecolumn.com/2008/01/mapreduce-a-major-step-back.html) as well as their [SIGMOD 2009](http://www.sigmod09.org/) paper, _[A Comparison of Approaches to Large-Scale Data Analysis](http://database.cs.brown.edu/projects/mapreduce-vs-dbms/)_.  Now I'm not about to jump into this whole dbms-is-better-than-mapreduce argument but I found Facebook's story line interesting:

> When we started at Facebook in 2007 all of the data processing infrastructure was built around a data warehouse built using a commercial RDBMS. The data that we were generating was growing very fast - as an example** we grew from a 15TB data set in 2007 to a 2PB data set today**. The infrastructure at that time was so inadequate that some daily data processing jobs were taking more than a day to process and the situation was just getting worse with every passing day. We had an urgent need for infrastructure that could scale along with our data and it was at that time we then started exploring Hadoop as a way to address our scaling needs.

> [The] Hive/Hadoop cluster at Facebook stores more than 2PB of uncompressed data and **routinely loads 15 TB of data daily**

Wow, 2PB of uncompressed data and growing at around 15TB daily.  A part of me wonders how much value there is in 2PB of data or if companies are suffering from  [OCD](http://en.wikipedia.org/wiki/Obsessive-compulsive_disorder) when it comes to data.  Either way it's interesting to see how much data is being generated/collected and how engineers are dealing with it.
