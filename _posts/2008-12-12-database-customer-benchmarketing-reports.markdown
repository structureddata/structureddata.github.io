---
author: Greg Rahn
comments: true
date: 2008-12-12T09:00:02.000Z
layout: post
slug: database-customer-benchmarketing-reports
title: Database Customer Benchmarketing Reports
wp_id: 313
wp_categories:
  - Data Warehousing
  - Oracle
  - Performance
wp_tags:
  - benchmarketing
  - data warehouse
  - Data Warehouse Appliance
  - data warehouse appliances
  - data warehouse technology
  - Data Warehousing
  - database customer benchmarks
  - database performance
  - DBMS
  - dw appliance
  - Exadata
  - fast query processing
  - Netezza
  - Oracle
  - Query Performance
  - Vertica
---

A few weeks ago I read Curt Monash's report on [interpreting the results of data warehouse proofs-of-concept (POCs)](http://www.dbms2.com/2008/11/19/data-warehouse-proof-of-concept-pocs/) and I have to say, I'm quite surprised that this topic hasn't been covered more by analysts in the data warehousing space.  I understand that analysts are not database performance engineers, but where do they think that the performance claims of 10x to 100x or more come from?  Do they actually  investigate these claims or just report on them?  I can not say that I have ever seen any database analyst offer any technical insight into these boasts of performance.  If some exist be sure to leave a comment and point me to them.

[Oracle Exadata](http://oracle.com/exadata) Performance Architect [Kevin Closson](http://kevinclosson.wordpress.com/) has blogged about a [485x performance increase of Oracle Exadata vs. Oracle Exadata](http://kevinclosson.wordpress.com/2008/12/10/oracle-exadata-storage-server-485x-faster-thanoracle-exadata-storage-server-part-i/trackback/) and his [follow-up post to explain exactly where the 485x performance gain comes from](http://kevinclosson.wordpress.com/2008/12/11/exadata-storage-server-485x-faster-thanexadata-storage-server-part-ii/trackback/) gave me the nudge to finish this post that had been sitting in my drafts folder since I first read Curt's post.

### Customer Bechmarketing Claims

I thought I would compile a list  of what the marketing folks at other database vendors are saying about the performance of their products.  Each of these statements have been taken from the given vendor's website.

- **Netezza**: 10-100 times faster than traditional solutions...but it is not uncommon to see performance differences as large as 200x to even 400x or more when compared to existing Oracle systems
- **Greenplum**: often 10 to 100 times faster than traditional solutions
- **DATAllegro**: 10-100x performance over traditional platforms
- **Vertica**: Performs 30x-200x faster than other solutions 
- **ParAccel**: 20X - 200X performance gains
- **EXASolution**: can perform up to 100 times faster than with traditional databases
- **Kognitio WX2**: Tests have shown to out-perform other database / data warehouse solutions by 10-60 times

Certainly seems these vendors are a positioning themselves against _traditional_ database solutions, whatever that means.  And differences as large as _400x_ against Oracle?  What is it _exactly_ they are comparing?

### Investigative Research On Netezza's Performance Claims

Using my favorite Internet search engine I came across [this presentation](http://www.acs.org.au/nsw/sigs/bi/Netezzathedatawarehouseappliance.pdf) by Netezza dated October 2007.  On slide 21 Netezza is comparing an NPS 8150 (112 SPU, up to 4.5 TB of user data) server to IBM DB2 UDB on a p680 with 12 CPUs (the existing solution).  Not being extremely familiar with the IBM hardware mentioned, I thought I'd research to see exactly what an IBM p680 server consists of.  The first link in my search results took me to [here](http://www-03.ibm.com/systems/p/hardware/pseries/highend/p680/index.html) where the web page states:


> The IBM eServer pSeries 680 has been withdrawn from the market, effective March 28, 2003.


Searching a bit more I came across [this page](http://www-03.ibm.com/systems/p/hardware/whitepapers/p680_technology.html) which states that the 12 CPUs in the pSeries 680 are RS64 IV microprocessors.  According to [Wikipedia](http://en.wikipedia.org/wiki/IBM_RS64#RS64-IV) the "RS64-IV or Sstar was introduced in 2000 at 600 MHz, later increased to 750 MHz".  Given that at best, the p680 had 12 CPUs running at 750 MHz and the NPS 8150 had 112 440GX PowerPC processors I would give the compute advantage to Netezza by a significant margin.  I guess it is cool to brag how your most current hardware beat up on some old used and abused server who has already been served its end-of-life notice.  I found it especially intriguing that Netezza is boasting about beating out an IBM p680 server that has been end-of-lifed more than four years prior to the presentation's date.  Perhaps they don't have any more recent bragging to do?

Going back one slide to #20 you will notice a comparison of Netezza and Oracle.  Netezza clearly states they used a NPS 8250 (224 SPUs, up to 9 TB of user data) against Oracle 10g RAC running on Sun/EMC.  Well ok...Sun/EMC what???  Obviously there were at least 2 Sun servers, since Oracle 10g RAC is involved, but they don't mention the server models at all, nor the storage, nor the storage connectivity to the hosts.  Was this two or more [Sun Netra X1s](http://sunsolve.sun.com/handbook_pub/validateUser.do?target=Systems/Netra_X1/Netra_X1) or what???  Netezza boasts a 449x improvement in a "direct comparison on one day's worth of data".   What exactly is being compared is up to the imagination. I guess this could be one query or many queries, but the marketeers intentionally fail to mention.  They don't even mention the data set size being compared.  Given that Netezza can read data off the 224 drives at 60-70 MB/s, the NPS 8250 has a total scan rate of over 13 GB/s.  I can tell you first hand that there are very few Sun/EMC solutions that are configured to support 13 GB/s of I/O bandwidth.  Most configurations of that vintage probably don't support 1/10th of that I/O bandwidth (1.3 GB/s).

Here are a few more comparisons that I have seen in Netezza presentations:

- NPS 8100 (112 SPUs/4.5 TB max) vs. SAS on Sun E5500/6 CPUs/6GB RAM
- NPS 8100 (112 SPUs/4.5 TB max) vs. Oracle 8i on Sun E6500/12 CPUs/8 GB RAM
- NPS 8400 (448 SPUs/18 TB max) vs. Oracle on Sun (exact hardware not mentioned)
- NPS 8100 (112 SPUs/4.5 TB max) vs. IBM SP2 (database not mentioned)
- NPS 8150z (112 SPUs/5.5 TB max) vs. Oracle 9i on Sun/8 CPUs
- NPS 8250z (224 SPUs/11 TB max) vs. Oracle 9i on Sun/8 CPUs

As you can see, Netezza has a way of finding the oldest hardware around and then comparing it to its latest, greatest NPS.  Just like Netezza slogan, _[The Power to ]Question Everything™_, I suggest you question these benchmarketing reports.  Database software is only as capable as the hardware it runs on and when Netezza targets the worst performing and oldest systems out there, they are bound to get some good marketing numbers.  If they compete against the latest, greatest database software running on the latest, greatest hardware, sized competitively for the NPS being used, the results are drastically different.  I can vouch for that one first hand having done several POCs against Netezza.

### One Benchmarketing Claim To Rule Them All

Now, one of my favorite benchmarketing reports is one from Vertica. [ Michael Stonebraker's blog post on customer benchmarks](http://www.databasecolumn.com/2008/03/supporting-column-store-perfor.html) contains the following table:

![vertica_benchmark_table.png](/assets/vertica-benchmark-table.png)

Take a good look at the Query 2 results.  Vertica takes a query running in the current row store from running in 4.5 hours (16,200 seconds) to 1 second for a performance gain of 16,200x.  [Great googly moogly](http://www.youtube.com/watch?v=hSAXLayoMKI) batman, that is reaching [ludicrous speed](http://en.wikipedia.org/wiki/Spaceballs).  Heck, who needs 100x or 400x when you do 16,200x.  That surely warrants an explanation of the techniques involved there.  It's much, much more than simply column store vs. row store.  It does raise the question (at least to me): why Vertica doesn't run every query in 1 second.  I mean, come on, why doesn't that 19 minute row store query score better than a 30x gain?  Obviously there is a bit of the magic pixie dust going on here with, what I would refer to as "creative solutions" (in reality it is likely just a very well designed projection/materaizied view, but by showing the query and telling us how it was possible would make it less unimpressive [_sic_]).

### What Is Really Going On Here

First of all, you will notice that **not one** of these benchmarketing claims is against a vendor run system.  Each and every one of these claims are against **existing** customer systems. The main reason for this is that most vendors prohibit benchmark results being published with out prior consent from the vendor in the licensing agreement.  Seems the creative types have found that taking the numbers from the existing, production system is not prohibited in the license agreement so they compare that to their latest, greatest hardware/software and execute or supervise the execution of a benchmark on their solution.  Obviously this is a one sided apples to bicycles comparison, but quite favorable for bragging rights for the new guy.

I've been doing customer benchmarks and proof of concepts (POCs) for almost 5 years at Oracle.  I can guarantee you that Netezza has never even come close to getting 10x-100x the performance over Oracle running on a competitive hardware platform.  Now I can say that it is not uncommon for Oracle running on a balanced system to perform 10x to 1000x (ok, in extreme cases) over an _existing_ poorly performing Oracle system.  All it takes is to have a very unbalanced system with no I/O bandwidth, not be using parallel query, not use compression, poor or no use of partitioning and you have created a springboard for any vendor to look good.

### One More Juicy Marketing Tidbit

While searching the Internet for creative marketing reports I have to admit that the crew at ParAccel probably takes the cake (and not in an impressive way).  On one of their web pages they have these bullet points (plus a few more uninteresting ones):

- All operations are done in parallel (A non-parallel DBMS must scan all of the data sequentially)
- Adaptive compression makes disks faster...

Ok, so I can kinda, sorta see the point that a non-parallel DBMS must do something sequentially...not sure how else it would do it, but then again, I don't know any enterprise database that is not capable of parallel operations.  However, I'm going to need a bit of help on the second point there...how exactly does compression make disks faster?  Disks are disks.  Whether or not compression is involved has nothing to do with how fast a disk is.  Perhaps they mean that compression can increase the logical read rate from a disk given that compression allows more data to be stored in the same "space" on the disk, but that clearly **is not** what they have written.  Reminds me of [DATAllegro's faster-than-wirespeed claims on scan performance](http://kevinclosson.wordpress.com/2008/07/07/i-know-nothing-about-data-warehouse-appliances-and-now-so-wont-you-part-ii-datallegro-supercharges-fibre-channel-performance/).  Perhaps these marketing guys should have their numbers and wording validated by some engineers.

### Do You Believe In Magic Or Word Games?

Creditable performance claims need to be accounted for and explained.  Neil Raden from [Hired Brains Research](http://www.hiredbrains.com/) offers guidance for evaluating benchmarks and interpreting market messaging in his paper, [Questions to Ask a Data Warehouse Appliance Vendor](http://www.hiredbrains.com/HB-QuestionsWP.pdf).  I think Neil shares the same opinion of these silly benchmarketing claims.  Give his paper a read.
