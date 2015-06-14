---
author: Greg Rahn
comments: true
date: 2010-10-13
layout: post
slug: emc-greenplum-data-computing-appliance-real-world-benchmarks
title: EMC Greenplum Data Computing Appliance Real World Benchmarks
wp_id: 1220
wp_tags:
  - benchmarks
  - EMC
  - Greenplum
---

Today EMC Greenplum (I guess that is the "official" name since the acquisition) launched their new product offering and as part of that announcement they published some performance numbers around data loading rates.  Let's examine what's behind this loading rate number.

### Real-World Benchmarks

Benchmarks and benchmark results are often criticized (and sometimes rightfully so) because they often are (over) engineered to prove a point and may include optimizations or techniques that would be uncommon in day to day operations.  I think most everyone knows and agrees with that.  In the interest of providing benchmark numbers that are not over engineered, Greenplum states the following [1]:

> Greenplum and the EMC Data Computing Products Division are now producing real world benchmarks. No more obscure tests against formula-one tuning. Instead we would like to present the beginning of what we are calling real-world benchmarks. These benchmarks are designed to reflect the true customer experience and conform to the following guiding principles:
> 
>   * Test on the system as it leaves the factory, not the laboratory.
>   * Create data types and schemas that match real-world use cases.
>   * Consider options beyond raw bulk loading.

I think that list of good intentions is commendable, especially since I fondly remember EMC data sheets that had IOPS rates that were 100% from the array cache.  Hopefully those days are behind them.

### The Data Loading Rate Claim

As part of Greenplum's data loading rate claims, there are two papers written up by Massive Data News that contain some details about these data loading benchmarks, one for Internet and Media [2], and one for Retail [3].  Below is the pertinent information.

**Application Configuration**

Configuration | Option (Internet and Media) | Option (Retail)
--- | --- | ---
Segment servers	16 | (standard GP1000 configuration) | 16 (standard GP1000 configuration)
Table format | Quicklz columnar | Quicklz columnar
Mirrors | Yes (two copies of the data) | Yes (two copies of the data)
Gp_autostats_mode | None | None
ETL hosts | 20, 2 URLs each | 20, 2 URLs each
Rows loaded | 320,000,000 | 320,000,000
Row width | 616 bytes/row | 666 bytes/row

The only difference between these two tables is the number/types of columns and the row width.

**Benchmark Results**

Metric | Results (Internet and Media) | Results (Retail)
--- | --- | --- 
Rows per Second | 5,530,000 | 4,770,000
TB per Hour | 11.16 | 10.4
Time to load 1 Billion rows | 3.01 Minutes | 3.48 Minutes


**Derived Metrics**

Metric | Value (Internet and Media) | Value (Retail)
--- | --- | ---
Total Flat File Size | 198 GB | 214 GB
Data per ETL host | 9.9 GB | 10.7 GB
Time to load 320M rows | 0.9632 Minutes | 1.1136 Minutes


When I looked over these metrics the following stood out to me:

- Extrapolation is used to report the time to load 1 billion rows (only 320 million are actually loaded).
- Roughly 60 seconds of loading time is used to extrapolate an hourly loading rate.
- The source file size per ETL host is very small; small enough to fit entirely in the file system cache.

Now why are these "red flags" to me for a "real-world" benchmark?

- Extrapolation always shows linear rates.  If Greenplum wants to present a real-world number to load 1 billion rows, then load at least 1 billion rows.  It can't be that hard, can it?
- Extrapolation of the loading rate is at a factor of ~60x (extrapolating a 1 hour rate from 1 minute of execution).  I'd be much more inclined to believe/trust a rate that was only extrapolated 2x or 4x, but 60x is way too much for me.
- If the source files fit entirely into file system cache, no physical I/O needs to be done to stream that data out.  It should be fairly obvious that no database can load data faster than the source system can deliver that data, but at least load more data than aggregate memory on the ETL nodes to eliminate the fully cached effect.
- There are 20 ETL nodes feeding 16 Greenplum Segment nodes.  Do real-world customers have more ETL nodes than database nodes?  Maybe, maybe not.
- No configuration is listed for the ETL nodes.

Now don't get me wrong.  I'm not challenging that EMC Greenplum Data Computing Appliance can't do what is claimed.  But surely the data that supports those claims has significant room for improvement, especially for a company that is claiming to be in favor of open and real-world benchmarks.  Hopefully we see some better quality real-world benchmarks from these guys in the future.

### The Most Impressive Metric

Loading rate aside, I found the most impressive metric was that EMC Greenplum can fit 18 servers in a rack that is just 7.5 inches tall (or is it 190 cm?) [4]. [![](/assets/gp100.png)](/assets/gp100.png)

## References

*  [1] [http://www.greenplum.com/resources/data-loading-benchmarks/](http://www.greenplum.com/resources/data-loading-benchmarks/) 
*  [2] [http://www.greenplum.com/pdf/gpdf/RealWorldBenchmarks_InternetMedia.pdf](http://www.greenplum.com/pdf/gpdf/RealWorldBenchmarks_InternetMedia.pdf) 
*  [3] [http://www.greenplum.com/pdf/gpdf/RealWorldBenchmarks_Retail.pdf](http://www.greenplum.com/pdf/gpdf/RealWorldBenchmarks_Retail.pdf) 
*  [4] [http://www.greenplum.com/pdf/EMC-Greenplum_DCA_DataSheet.pdf](http://www.greenplum.com/pdf/EMC-Greenplum_DCA_DataSheet.pdf)
