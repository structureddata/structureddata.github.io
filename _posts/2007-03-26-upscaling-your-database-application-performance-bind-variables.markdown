---
author: Greg Rahn
comments: true
date: 2007-03-26T16:00:09.000Z
layout: post
slug: upscaling-your-database-application-performance-bind-variables
title: 'Upscaling Your Database Application Performance: Bind Variables'
wp_id: 9
wp_categories:
  - Performance
---

Recently I've had several encounters with issues that I would consider to be part of _basic_ scalable application design.  These aren't design issues that are new.  Most of them have been addressed many times over the past years, however, they are issues that continually seem to appear.  My guess is that it's not the same people making the same mistakes, but rather new people making the same mistakes.  Each of my next few posts will be taking one of these application design issues and addressing it.

### Bind Variables

I think Tom Kyte's statement from [Expert One-on-One Oracle](http://www.amazon.com/Expert-One-Oracle-Thomas-Kyte/dp/1861004826/ref=sr_1_4/103-9209437-0964637?ie=UTF8&s=books&qid=1174719901&sr=8-4) says it best:

> If I were to write a book about how to build _nonscalable_ Oracle applications, then "Don't use Bind Variables" would be the first and last chapters.

If Tom wrote that in his book which was published in 2001, why do I see OLTP applications today that do not use bind variables?

Let's next consider the three categories of application coding from [Designing Applications For Performance And Scalability](http://www.oracle.com/technology/deploy/performance/pdf/designing_applications_for_performance_and_scalability.pdf).  I'd like to focus on the 24 concurrent session numbers from Picture 2 and Picture 3.

![Picture 2](/assets/picture2.jpg)

![Picture 3](/assets/picture3.jpg)

By using the repeating execute only logic the optimal performance is achieved - around a 45x improvement over using literal values (2100 vs. 48).

Below is a slide from the [OOW2006 Real World Performance Session I](http://www28.cplan.com/cc139/catalog.jsp?ilc=139-1&ilg=english&isort_sessions=&isort_demos=&isort_exhibitors=&is=yes&ip=%3C%2Fipresentations%3E&search_sessions=yes&icriteria3=+&icriteria1=+&icriteria9=+&icriteria6=&icriteria8=&icriteria4=+&icriteria5=S281239&icriteria7=+).

![Performance Basics](/assets/perf_basics_480.jpg)

For this workload, the optimal implementation scales almost 2x on the same hardware compared to the implementation with hard parsing and `cursor_sharing=force`.  My point here is that even though one can set cursor_sharing=force, it still does not provide the same scalability that implementing the optimal logic at the application level can provide.

The topic of [Good Cursor Usage and Management](http://download-west.oracle.com/docs/cd/B19306_01/server.102/b14211/design.htm#sthref168) is also discussed in the [Oracle Database Performance Tuning Guide](http://download-west.oracle.com/docs/cd/B19306_01/server.102/b14211/toc.htm).  The Performance Tuning Guide is not just for DBAs, it contains many suggested programming techniques for scalable applications.

I could go into numerous examples but I think the point I'm trying to make here is quite clear.  As an application developer there is a great opportunity to "build in" (or leave out!) scalability into an application.  If you think you can code however you choose and then turn it over to the DBA to "tune the database" at a later time, you are quite naive.  I think this proverb says it best: "[An ounce of prevention is worth a pound of cure](http://www.bartleby.com/59/3/ounceofpreve.html)".  When it comes to designing your next application, seriously consider the limitations of scalability you build into it.  Using bind variables is my OLTP scalable programming rule #1.
