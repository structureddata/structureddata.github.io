---
author: Greg Rahn
comments: true
date: 2011-10-17T21:05:49.000Z
layout: post
slug: counting-triangles-faster
title: Counting Triangles Faster
wp_id: 1559
wp_categories:
  - Oracle
  - Parallel Execution
  - Performance
wp_tags:
  - graph analysis
  - Oracle
  - Vertica
---

A few weeks back one of the Vertica developers put up a [blog post on counting triangles](http://www.vertica.com/2011/09/21/counting-triangles/) in an undirected graph with reciprocal edges.  The author was comparing the size of the data and the elapsed times to run this calculation on Hadoop and Vertica and put up the work on github and encouraged others: "do try this at home."  So I did.

### Compression

Vertica draws attention to the fact that their compression brought the size of the 86,220,856 tuples down to 560MB in size, from a flat file size of 1,263,234,543 bytes resulting in around a 2.25X compression ratio.  My first task was to load the data and see how Oracle's Hybrid Columnar Compression would compare.  Below is a graph of the sizes.

[![](/assets/compression.png)](/assets/compression.png)

As you can see, Oracle's default HCC query compression (query high) compresses the data over 2X more than Vertica and even HCC query low compression beats out Vertica's compression number.  

### Query Elapsed Times

The closest gear I had to Vertica's hardware was an [Exadata X2-2](http://www.oracle.com/technetwork/database/exadata/dbmachine-x2-2-datasheet-175280.pdf) system -- both use 2 socket, 12 core Westmere-EP nodes.  While one may try to argue that Exadata may somehow influence the execution times, I'll point out that I was using [In-Memory Parallel Execution](http://download.oracle.com/docs/cd/E11882_01/server.112/e25554/px.htm#BCECBIDF) so no table data was even read from spinning disk or Exadata Flash Cache -- it's all memory resident in the database nodes' buffer cache.  This seems to be inline with how Vertica executed their tests though not explicitly stated (it's a reasonable assertion).  

After I loaded the data and gathered table stats, I fired off the exact same SQL query that Vertica used to count triangles to see how Oracle would compare.  I ran the query on 1, 2 and 4 nodes just like Vertica.  Below is a graph of the results.

[![](/assets/elapsed1.png)](/assets/elapsed1.png)

As you can see, the elapsed times are reasonably close but overall in the favor of Oracle winning 2 of the 3 scale points as well as having a lower sum of the three executions:  Vertica 519 seconds, Oracle 487 seconds -- advantage Oracle of 32 seconds.

### It Should Go Faster!

As a database performance engineer I was thinking to myself, "it really should go faster!"  I took a few minutes to look over things to see what could make this perform better.  You might think I was looking at parameters or something like that, but you would be wrong.  After a few minutes of looking at the query and the execution plan it became obvious to me -- it could go faster!  I made a rather subtle change to the SQL query and reran my experiments.  With the modified SQL query Oracle was now executing twice as fast on 1 node than Vertica was on 4 nodes.  Also, on 4 nodes, the elapsed time came in at just 14 seconds, compared to the 97 seconds Vertica reported -- a difference of almost 7X!  Below are the combined results.

[![](/assets/elapsed2.png)](/assets/elapsed2.png)

### What's The Go Fast Trick?

I was thinking a bit more about the problem at hand -- we need to count vertices but not count them twice since they are reciprocal.  Given that for any edge, it exists in both directions, the query can be structured like Vertica wrote it -- doing the filtering with a join predicate like **e1.source < e2.source** to eliminate the duplicates or we can simply use a single table filter predicate like **source < dest** _before_ the join takes place.  One of the first things they taught me in query planning and optimization class was to filter early!  That notation pays off big here because the early filter cuts the rows going into the first join as well as the output of the first join by a factor of 2 -- 1.8 billion rows output vs. 3.6 billion.  That's a huge savings not only in the first join, but also in the second join as well.

Here is what my revised query looks like: 

```
with
  e1 as (select * from edges where source < dest),
  e2 as (select * from edges where source < dest),
  e3 as (select * from edges where source > dest)
select count(*)
from e1
join e2 on (e1.dest = e2.source)
join e3 on (e2.dest = e3.source)
where e3.dest = e1.source
```

### Summary

First, I'd like to thank the Vertica team for throwing the challenge out there and being kind enough to provide the data, code and their elapsed times.  I always enjoy a challenge -- especially one that I can improve upon.  Now, I'm not going to throw any product marketing nonsense out there as that is certainly not my style (and there certainly is more than enough of that already), but rather I'll just let the numbers do the talking.  I'd also like to point out that this experiment was done without any structure other than the table.  And in full disclosure, all of my SQL commands are available as well.

The other comment that I would make is that the new and improved execution times really make a mockery of the exercise when comparing to Hadoop MapReduce or Pig, but I would also mention that this test case is extremely favorable for parallel pipelined databases that can perform all in-memory operations and given the data set is so small, this is the obviously the case.  Overall, in my opinion, a poor problem choice to compare the three technologies as it obviously (over) highlights the right tool for the job cliche.

Experiments performed on Oracle Database 11.2.0.2.

Github source code: [https://gist.github.com/gregrahn/1289188](https://gist.github.com/gregrahn/1289188)
