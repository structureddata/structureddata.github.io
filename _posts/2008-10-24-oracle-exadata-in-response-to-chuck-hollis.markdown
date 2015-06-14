---
author: Greg Rahn
comments: true
date: 2008-10-24T18:17:15.000Z
layout: post
slug: oracle-exadata-in-response-to-chuck-hollis
title: 'Oracle Exadata: In Response to Chuck Hollis'
wp_id: 221
wp_categories:
  - Exadata
  - Oracle
  - Performance
  - VLDB
wp_tags:
  - data bandwidth
  - Exedata
  - fibre channel storatge
  - Oracle
  - SAN Storage
  - scan rate
---

[Chuck Hollis](http://chucksblog.emc.com), VP and Global Marketing CTO at [EMC](http://emc.com) has written a couple blog posts offering his thoughts on [Oracle Exadata](http://oracle.com/exadata).  The first was ["Oracle Does Hardware"](http://chucksblog.emc.com/chucks_blog/2008/09/oracle-does-har.html) which he wrote the day after the product launch.  The second, unimpressively titled ["I Annoy Kevin Closson at Oracle"](http://chucksblog.emc.com/chucks_blog/2008/10/i-annoy-kevin-closson-at-oracle.html) was on Monday October 20th which was in response to [a blog post](http://kevinclosson.wordpress.com/2008/10/20/pessimistc-feelings-about-new-technology-oracle-exadata-storage-server-a-jbod-that-can-swamp-a-single-server/) by Exadata Performance Architect, [Kevin Closson](http://kevinclosson.wordpress.com) who commented on Chuck's first post and some comments left on Kevin's blog.

### Clearly Stated Intentions

Since Chuck had disabled comments for his "I Annoy Kevin" post, I'm going to write my comments here.  I have no intention to get into some fact-less debate turn flame, but I will make some direct comments with supporting facts and numbers while keeping it professional.

### Storage Arrays: Bottleneck or Not?

Chuck thinks:

> ...array-based storage technology is not the bottleneck; our work with Oracle [on the [Oracle Optimized Warehouse Initiative](http://www.oracle.com/solutions/business_intelligence/optimized-warehouse-initiative.html)] and other DW/BI environments routinely shows that we can feed data to a server just as fast as it can take it.

First let me comment on the Optimized Warehouse Initiative.  There have been some good things that have come out of this effort.  I believe it has increased the level of awareness when it comes to sizing storage for BI/DW workloads.  All too often storage sizing for BI/DW is done by capacity, not I/O bandwidth.  The focus is on building balanced systems: systems that can execute queries and workloads such that no one component (CPU/storage connectivity/disk array/disk drives) becomes the bottleneck prematurely.  The industry seems to agree:  IBM has the Balanced Warehouse and Microsoft has a reference architecture for Project Madison as well.

So the question comes back to: _Is array-based storage technology the bottleneck or not?_  I would argue it is.  Perhaps I would use a word other than "bottleneck", but let's be clear on the overall challenge here.  That is: to read data off disk with speed and efficiently return it to the database host to process it as fast as possible.

Let's start at the bottom of the stack: hard disk drives.  If the challenge is to scan lots of data fast, then how fast data can be read off disk is the first important metric to consider.  In the white paper [_Deploying EMC CLARiiON CX4-960 for Data Warehouse/Decision Support System (DSS) Workloads_](http://www.emc.com/collateral/hardware/white-papers/h5548-deploying-clariion-dss-workloads-wp.pdf) EMC reports a drive scan rate (for a BI/DW workload) of 20 MB/s using 8+1 RAID-5 and 33 MB/s using a 2+1 RAID-5 LUN configuration.  Oracle Exadata delivers drive scan rates  around 85 MB/s, a difference of 2.5X to 4.25X.  To understand the performance impact of this I've put together a few tables of data based on these real workload numbers.

### Hardware Specs and Numbers for Data Warehouse Workloads

<table cellpadding="1" width="100%" border="1">
    <tr> Storage RAID Raw:Usable Ratio Disk Drives Disk Scan Rate </tr>
    <tr>
        <td> EMC CX4-960 </td>
        <td> 8+1 RAID 5 </td>
        <td> 9:8 </td>
        <td> 146 GB FC 15k RPM </td>
        <td> 20 MB/s </td>
    </tr>
    <tr>
        <td> EMC CX4-960 </td>
        <td> 2+1 RAID 5 </td>
        <td> 3:2 </td>
        <td> 146 GB FC 15k RPM </td>
        <td> 33 MB/s </td>
    </tr>
    <tr>
        <td> EMC CX4-960 </td>
        <td> 8+1 RAID 5 </td>
        <td> 9:8 </td>
        <td> 300 GB FC 15k RPM </td>
        <td> 20 MB/s </td>
    </tr>
    <tr>
        <td> EMC CX4-960 </td>
        <td> 2+1 RAID 5 </td>
        <td> 3:2 </td>
        <td> 300 GB FC 15k RPM </td>
        <td> 33 MB/s </td>
    </tr>
    <tr>
        <td>Oracle Exadata </td>
        <td> ASM Mirroring </td>
        <td> 2:1 </td>
        <td> 450 GB SAS 15k RPM </td>
        <td> 85 MB/s </td>
    </tr>
</table>
<br>

#### Sizing By Capacity

<table cellpadding="1" width="100%" border="1">
    <tr> Storage RAID Total Usable Space Disk Drive Number of Drives Total Scan Rate </tr>
    <tr>
        <td>EMC CX4-960 </td>
        <td> 8+1 RAID 5 </td>
        <td> 18 TB </td>
        <td> 146 GB </td>
        <td> 139 </td>
        <td> 2.8 GB/s </td>
    </tr>
    <tr>
        <td>EMC CX4-960 </td>
        <td> 2+1 RAID 5 </td>
        <td> 18 TB </td>
        <td> 146 GB </td>
        <td> 185 </td>
        <td> 6.1 GB/s* </td>
    </tr>
    <tr>
        <td>EMC CX4-960 </td>
        <td> 8+1 RAID 5 </td>
        <td> 18 TB </td>
        <td> 300 GB </td>
        <td> 68 </td>
        <td> 1.4 GB/s </td>
    </tr>
    <tr>
        <td>EMC CX4-960 </td>
        <td> 2+1 RAID 5 </td>
        <td> 18 TB </td>
        <td> 300 GB </td>
        <td> 90 </td>
        <td> 3.0 GB/s </td>
    </tr>
    <tr>
        <td>Oracle Exadata </td>
        <td> ASM Mirroring </td>
        <td> 18 TB </td>
        <td> 450 GB </td>
        <td> 80 </td>
        <td> 6.8 GB/s </td>
    </tr>
</table>

(*) I'm not sure that the CX4-960 array head is capable of 6.1 GB/s so it likley takes at least 2 CX4-960 array heads to deliver this throughput to the host(s

#### Sizing By Scan Rate

<table cellpadding="1" width="100%" border="1">
    <tr> Storage RAID Total Scan Rate Disk Drive Number of Drives Total Usable Space </tr>
    <tr>
        <td>EMC CX4-960 </td>
        <td> 8+1 RAID 5 </td>
        <td> 3.00 GB/s </td>
        <td> 146 GB </td>
        <td> 150 </td>
        <td> 19.46 TB </td>
    </tr>
    <tr>
        <td>EMC CX4-960 </td>
        <td> 2+1 RAID 5 </td>
        <td> 3.00 GB/s </td>
        <td> 146 GB </td>
        <td> 90 </td>
        <td> 8.76 TB </td>
    </tr>
    <tr>
        <td>EMC CX4-960 </td>
        <td> 8+1 RAID 5 </td>
        <td> 3.00 GB/s </td>
        <td> 300 GB </td>
        <td> 150 </td>
        <td> 40.00 TB </td>
    </tr>
    <tr>
        <td>EMC CX4-960 </td>
        <td> 2+1 RAID 5 </td>
        <td> 3.00 GB/s </td>
        <td> 300 GB </td>
        <td> 90 </td>
        <td> 18.00 TB </td>
    </tr>
    <tr>
        <td>Oracle Exadata </td>
        <td> ASM Mirroring </td>
        <td> 3.00 GB/s </td>
        <td> 450 GB </td>
        <td> 36 </td>
        <td> 8.10 TB </td>
    </tr>
</table>

<br>

### A Few Comments On The Above Data Points

Please note that "Total Usable Space" is a rough number for the total protected disk space one can use for a database if you filled each drive up to capacity.  It does not take into consideration things like loss for formatting, space for sort/temp, etc, etc.  I would use a 60% rule for estimating data space for database vs. total usable space.  This means that 18 TB of total usable space would equate to 10 TB (max) of space for database data (compression not accounted for).

I'd also like to note that in the Sizing By Capacity table the "Total Scan Rate" is a disk only calculation.  Whether or not a single CX4-960 array head can move data at that rate is in question.  Based on the numbers in the EMC whitepaper it would appear CX4-960 head is capable of 3 GB/s but I would question if it is capable of much more than that, hence the reason for the asterisk(*).

### Looking At The Numbers

If you look at the number for Sizing By Capacity, you can see that for the given fixed size, Exadata provides the fastest scan rate while using only 80 disk drives.  The next closest scan rate is just 700 MB/s less but it uses 105 more disk drives (80 vs. 185).  Quite a big difference.

When it comes to delivering I/O bandwidth, Exadata clearly stands out.  Targeting a scan rate of 3 GB/s, Exadata delivers this using only 36 drives, just 3 Exadata Storage Servers.  If one wanted to deliver this scan rate with the CX4 it would take 2.5X as many drives (90 vs. 36) using 2+1 RAID 5.

So are storage arrays the bottleneck?  You can draw your own conclusions, but I think the numbers speak to the performance advantage with Oracle Exadata when it comes to delivering I/O bandwidth and fast scan rates.  Consider this:  What would the storage topology look like if you wanted to [deliver a scan rate of 74 GB/s](http://structureddata.org/2008/09/28/oracle-exadata-storage-server-and-the-hp-oracle-database-machine/) as we did for Oracle OpenWorld with 84 HP Oracle Exadata Storage Servers (6 HP Oracle Database Machines)?  Honestly I would struggle to think where I would put the 185 or so 4Gb HBAs to achieve that.

### Space Saving RAID or Wasteful Mirroring

This leads me to another comment by Chuck in his second post:

> [with Exadata] The disk is mirrored, no support of any space-saving RAID options -- strange, for such a large machine

And this one in his first post:

> If it were me, I'd want a RAID 5 (or 6) option

And [his comment](http://kevinclosson.wordpress.com/2008/10/09/800/#comment-33153) on Kevin's blog:

> The fixed ratio of 12 disks (6 usable) per server element strikes us as a bit wasteful....And, I know this only matters to storage people, but there’s the minor matter of having two copies of everything, rather than the more efficient parity RAID approaches. Gets your attention when you’re talking 10-40TB usable, it does.

Currently Exadata uses ASM mirroring for fault tolerance so there is a 2:1 ratio of raw disk to usable disk, however I don't think it matters much.  The logic behind that comment is that when one is sizing for a given scan rate, Exadata uses less spindles than the other configurations even though the disk protection is mirroring and not space-saving RAID 5.  I guess I think it is strange to worry about space savings when disks just keep getting bigger and many are keeping the same performance characteristics as their predecessors.  Space is cheap.  Spindles are expensive.  When one builds a configuration that satisfies the I/O scan rate requirement, chances are you have well exceeded the storage capacity requirement, even when using mirroring.

Perhaps Chuck likes space-saving RAID 5, but I think using less drives (0.4 as many, 36 vs. 90) to deliver the same scan rate is hardly wasteful.  You know what really gets my attention?  Having 40 TB of total usable space on 15 HP Oracle Exadata Storage Servers (180 450GB SAS drives) and being able to scan it at 15 GB/s compared to say having a CX4 with 200 drives @ 300GB using 2+1 R5 and only being able to scan them at 6.6 GB/s.  I'd also be willing to bet that would require at least 2 if not 3 CX4-960 array heads and at least 30 4Gb HBAs running at wire speed (400 MB/s).

### Exadata Is Smart Storage

[Chuck comments](http://kevinclosson.wordpress.com/2008/10/09/800/#comment-33153):

> Leaving hardware issues aside, how much of the software functionality shown here is available on generic servers, operating systems and storage that Oracle supports today? I was under the impression that most of this great stuff was native to Oracle products, and not a function of specific tin …
> If the Exadata product has unique and/or specialized Oracle logic, well, that’s a different case.


After reading that I would said Chuck has not read the [_Technical Overview of the HP Oracle Exadata Storage Server_](http://www.oracle.com/technology/products/bi/db/exadata/pdf/exadata-technical-whitepaper.pdf).  Not only does Exadata have a very fast scan rate, it has intelligence.  A combination of brawn and brains which is not available with other storage platforms.  The Oracle Exadata Storage Server Software (say that 5 times fast!!!) is not an Oracle database.  It is storage software not database software.  The intelligence and specialized logic is that Exadata Smart Scans return only the relevant rows and columns of a query, allowing for better use of I/O bandwidth and increased database performance because the database host(s) are not issuing I/O requests for data that is not needed for the query and then processing it post-fact.  There are a couple slides (18 & 19) referencing a simple example of the benifits of Smart Scans in the [HP Oracle Exadata Storage Server technical overview slide deck](http://www.oracle.com/technology/products/bi/db/exadata/pdf/exadata-storage-technical-overview.pdf).  It is worth the read.

### It Will Be Interesting Indeed

Chuck concludes his second post with:

> The real focus here should be software, not hardware.

Personally I think the focus should be on solutions that perform and scale and I think the [HP Oracle Exadata Storage Server](http://www.oracle.com/technology/products/bi/db/exadata/index.html) is a great solution for Oracle data warehouses that require large amounts of I/O bandwidth.

### Ending On A Good Note

While many comments by Chuck do not seem to be well researched I would comment that having a conventional mid-range storage array that can deliver 3 GB/s is not a bad thing at all.  I've seen many Oracle customers that have only a fraction of that and there are probably some small data warehouses out there that may run fine with 3 GB/s of I/O bandwidth.  However, I think that those would run even faster with Oracle Exadata and I've never had a customer complain about queries running too fast.
