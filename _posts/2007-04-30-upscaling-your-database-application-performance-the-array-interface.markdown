---
author: Greg Rahn
comments: true
date: 2007-04-30T12:00:39.000Z
layout: post
slug: upscaling-your-database-application-performance-the-array-interface
title: 'Upscaling Your Database Application Performance: The Array Interface'
wp_id: 14
wp_categories:
  - OLTP
  - Oracle
  - Performance
wp_tags:
  - array performance
  - jdbc array
---

Personally I believe the array interface is one of the most overlooked methods to increase database application scalability.  Any time an application is selecting or inserting more than a single row, performance benefits are generally observed by using the array interface.  The Oracle array interface exists for [Oracle Call Interface (OCI)](http://download-west.oracle.com/docs/cd/B19306_01/appdev.102/b14250/oci05bnd.htm#sthref671), [PL/SQL](http://download-west.oracle.com/docs/cd/B19306_01/appdev.102/b14261/tuning.htm#i48876), and [JDBC](http://download-west.oracle.com/docs/cd/B19306_01/java.102/b14355/oraperf.htm).

[Designing Applications For Performance And Scalability](http://www.oracle.com/technology/deploy/performance/pdf/designing_applications_for_performance_and_scalability.pdf) tells us:

> When more than one row is being sent between the client and the server, performance can be greatly enhanced by batching these rows together in a single network roundtrip rather than having each row sent in individual network roundtrips. This is in particular useful for INSERT and SELECT statements, which frequently process multiple rows and the feature is commonly known as the array interface.
> 
> To use the array interface, the client application will need to represent data as arrays rather than individual variables containing the data of a single row. For queries, most APIs perform automated array processing such that a client side fetch will return rows from an automatically buffered array fetch. This is known as prefetching. For INSERT statements, most APIs require the application code actually contain the array in the client side and use an array version of the bind and execute calls.

To demonstrate the performance benefit of using the array interface I wrote two simple Java programs: [batchInsert.java](/assets/batchinsert.java) and [rowPrefetch.java](/assets/rowprefetch.java).

### JDBC Array Inserts
I used [batchInsert.java](/assets/batchinsert.java) to insert 10,000 rows into the EMP table varying the batch size from 1 up to 50.  Below is a graph of the elapsed times at each batch size. 

![JDBC Update Batching Performance](/assets/jdbc-update-batching-performance.gif) 

As one can see by the results, leveraging the array interface for INSERT statements has significant performance gains, even with a small batch size, compared to the single row operation.  [Update Batching](http://download-west.oracle.com/docs/cd/B19306_01/java.102/b14355/oraperf.htm#i1056232) is discussed in more detail in the JDBC Developer's Guide.

### JDBC Array Selects
I ran some tests using [rowPrefetch.java](/assets/rowprefetch.java) which executes a SELECT against the 10,000 row EMP table without any predicate.  The prefetch batch size was tested at values between 1 and 10.  Below is a graph of the elapsed times. 

![JDBC Prefetch Performance](/assets//jdbc-prefetch-performance.gif) 

Setting the prefetch batch size to 5 yielded almost a 2x gain in response time compared to the single row operation.  Please see the [Row Prefetching](http://download-west.oracle.com/docs/cd/B19306_01/java.102/b14355/oraperf.htm#i1043756) section of the JDBC Developer's Guide for more details on the topic.

### Summary
The simple tests that were performed demonstrate that using the array interface yields noticable performance gains for both INSERT and SELECT statements.  The amount of performance gain will vary by application, but I'm most certain that gains will be observed if the operation is on more than a single row.  One should notice that leveraging the array interface not only reduces elapsed time, but also reduces the amount of CPU the operation consumes.  That sounds like a win-win to me and why I consider it an important part of database application scalability.  After all, the JDBC array interface is not in the [Performance Extensions](http://download-west.oracle.com/docs/cd/B19306_01/java.102/b14355/oraperf.htm) chapter for nothing, right?

### Test Environment
The simple tests I performed were run on a single CPU host running Windows XP Pro, Oracle 10.2.0.3.  If your application doesn't reside on the same host as the database, it is likely that you may see even greater gains do to the reduction of the network overhead.  As always, your mileage may vary.
