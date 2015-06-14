---
author: Greg Rahn
comments: true
date: 2009-09-01T14:03:16.000Z
layout: post
slug: oracle-database-11g-release-2-is-now-generally-available
title: Oracle Database 11g Release 2 Is Now Generally Available
wp_id: 651
wp_categories:
  - 11gR2
  - Oracle
wp_tags:
  - 11gR2
  - Oracle
---

Just a quick post to spread the news that Oracle Database 11g Release 2 is now generally available.  Download it for Linux today.  See the [press release](http://www.oracle.com/us/corporate/press/032365) for the usual details.

Here is an interesting tidbit of info from [a PC World article](http://www.pcworld.com/businesscenter/article/171192/oracle_11g_r2_makes_its_debut.html):

> The new release is the product of some 1,500 developers and 15 million hours of testing, according to Mark Townsend, vice president of database product management.

**Update:**  In reading [Lowering your IT Costs with Oracle Database 11g Release 2](http://www.oracle.com/technology/products/database/oracle11g/pdf/oracle-database-11g-release2-overview.pdf) I noticed this interesting tidbit:

> With Oracle Datanase 11g Release 2, the Exadata Storage servers also enable new hybrid columnar compression technology that provides up to a 10 times compression ratio, without any loss of query performance. And, for pure historical data, a new archival level of hybrid columnar compression can be used that provides up to 40 times compression ratios.

> Hybrid columnar compression is a new method for organizing how data is stored. Instead of storing the data in traditional rows, the data is grouped, ordered and stored one column at a time. This type of format offers a higher degree of compression for data that is loaded into a table for data warehousing queries. Different compression techniques can also be used on different partitions within a table.

Cool, Exadata now has column organized storage.  Things are certainly getting very interesting in Exadata land.

Be sure to check out the [Oracle Database 11g Release 2 New Features Guide](http://download.oracle.com/docs/cd/E11882_01/server.112/e10881/chapter1.htm#NEWFTCH1) for more goodies.

**Update 2:** For those attending OOW 2009, there will be a session on the new technology - Oracle's Hybrid Columnar Compression: The Next-Generation Compression Technology (S311358) on Tuesday 10/13/2009 13:00 - 14:00.
