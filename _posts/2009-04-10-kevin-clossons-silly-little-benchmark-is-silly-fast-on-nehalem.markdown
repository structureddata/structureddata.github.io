---
author: Greg Rahn
comments: true
date: 2009-04-10T21:23:08.000Z
layout: post
slug: kevin-clossons-silly-little-benchmark-is-silly-fast-on-nehalem
title: "Kevin Closson's Silly Little Benchmark Is Silly Fast On Nehalem"
wp_id: 489
wp_categories:
  - Oracle
  - Performance
wp_tags:
  - mac pro
  - memhammer
  - nehalem
  - silly little benchmark
---

Recently [Kevin Closson](http://kevinclosson.wordpress.com) wrote about the [absurdly simple NUMA requirements for TPC-C on the new Intel Nehalem](http://kevinclosson.wordpress.com/2009/03/30/oracle-database-11g-with-intel-xeon-5570-tpc-c-result-astounding-yes-but-beware-of-the-absurdly-difficult-numa-software-configuration-requirements/) platform and I also mentioned my excitement that [databases run 2X faster on Nehalem 5500 series compared to the Intel 5400 series processors](http://structureddata.org/2009/04/01/intel-nehalem-ep-xeon-5500-series-processors-makes-databases-go-2x-faster/).  I do have to give credit to Kevin for being excited about Nehalem (the processors, not the river,  [though that is a very nice fish he caught](http://kevinclosson.wordpress.com/2007/03/29/oracle-on-virtual-machines-going-fishing-intel-%E2%80%9Cnehalem%E2%80%9D-xeon-quad-core-with-csi-floats/)) way back in March of 2007 when he wrote:

> [Nehalem] are quad core processors that are going to pack a very significant punch—much more so than the AMD Barcelona processor expected later this year [in 2007]

I also came across [Kevin's Silly Little Bechmark (SLB)](http://kevinclosson.wordpress.com/2007/01/30/oracle-on-opteron-with-linux-the-numa-angle-part-iii/) and wanted to give it a run on my new [Nehalem Mac Pro](http://www.apple.com/macpro/) and see how it compares to the dual-core Opteron 800 series processor in the DL585 Kevin posted results for on his blog.  Unfortunately I _only_ have the entry level Mac Pro with the single 2.66GHz Quad-Core Intel Xeon Nehalem processor and 3 GB of memory.   Although, if you have $12,000 burning a hole in your pocket you could snag a 2 x 2.93GHz Quad-Core version and stuff it with 32 GB of memory.  I'm quite certain you'll have to add a [5 point racing harness](http://www.racingseatsonline.com/Racing-Seat-Belts-&-Harnesses/c216/p5800/Race-Quip-5-Point-H-Style-Latch-&-Link-Harness/product_info.html?osCsid=58c318c638eb1d2c964459491ba51e4e) to your desk chair to operate it though.  Don't take my word for it though - see the [Geekbench results](http://browse.geekbench.ca/geekbench2/top).  My Mac Pro [Geekbench result](http://browse.geekbench.ca/geekbench2/view/126113) blows away the [PC system](http://browse.geekbench.ca/geekbench2/view/126557) it is replacing.  Anyway back to the SLB tests...

### SLB Test Setup (Memhammer)

Here is the script (./slb) I ran to test out the Mac Pro:

```
# !/bin/bash
uname -a date
echo "One memhammer crushing 1GB physical memory:" ./create_sem ./memhammer 262144 6000
echo "Reduce the memory to facilitate 1-4 scale-up test" echo "1 thread .25GB:" ./create_sem ./memhammer 65536 6000
echo "2 threads .25GB each:" ./create_sem ./memhammer 65536 6000 & ./memhammer 65536 6000 & ./trigger wait
echo "4 threads .25GB each:" ./create_sem ./memhammer 65536 6000 & ./memhammer 65536 6000 & ./memhammer 65536 6000 & ./memhammer 65536 6000 & ./trigger wait
```

### SLB Results

Let's fire off memhammer and make that CPU sweat!

```
# ./slb
Darwin greg-rahns-mac-pro.local 9.6.3 Darwin Kernel Version 9.6.3: Tue Jan 20 18:26:40 PST 2009; root:xnu-1228.10.33~1/RELEASE_I386 i386
Fri Apr 10 11:48:06 PDT 2009
One memhammer crushing 1GB physical memory:
Total ops 1572864000  Avg nsec/op    30.6  gettimeofday usec 48204156 TPUT ops/sec 32629219.8
Reduce the memory to facilitate 1-4 scale-up test
1 thread .25GB:
Total ops 393216000  Avg nsec/op    30.7  gettimeofday usec 12059811 TPUT ops/sec 32605486.1
2 threads .25GB each:
Total ops 393216000  Avg nsec/op    32.0  gettimeofday usec 12593203 TPUT ops/sec 31224462.9
Total ops 393216000  Avg nsec/op    32.0  gettimeofday usec 12593862 TPUT ops/sec 31222829.0
4 threads .25GB each:
Total ops 393216000  Avg nsec/op    36.6  gettimeofday usec 14391042 TPUT ops/sec 27323664.3
Total ops 393216000  Avg nsec/op    36.6  gettimeofday usec 14394529 TPUT ops/sec 27317045.2
Total ops 393216000  Avg nsec/op    36.7  gettimeofday usec 14423406 TPUT ops/sec 27262354.0
Total ops 393216000  Avg nsec/op    36.7  gettimeofday usec 14449585 TPUT ops/sec 27212961.5
```

Pretty good stuff!  Right around 33 nanoseconds per operation.  Blazing fast!

### 2.66GHz Quad-Core Intel W3520 Nehalem Vs. AMD 2.20GHz Dual-Core Opteron 800 Series

Below are my Mac Pro results compared to the DL585 AMD results Kevin posed.

```
Command line: ./memhammer 262144 6000

# Mac Pro @ 2.66GHz Quad-Core Intel Xeon Nehalem (model W3520)
Total ops 1572864000 Avg nsec/op 30.7 gettimeofday usec  48292072 TPUT ops/sec 32569818.1

# HP DL585 @ 2.200GHz Dual-Core Opteron 800 series
Total ops 1572864000 Avg nsec/op 68.8 gettimeofday usec 108281130 TPUT ops/sec 14525744.2
```

The Mac Pro's Nehalam processor is just over 2X as fast to perform the operation (30.7 ns vs. 68.8 ns) and thus does just over 2X the operations per second (32569818.1 ops/s vs. 14525744.2 ops/s).  This Nehalem Mac Pro is simply amazing and definitely a beast on the inside.  Can you imagine the compute power Virginia Tech would have if they upgraded their [324 dual-processor quad-core 2.8GHz Penryn Mac Pros](http://arstechnica.com/apple/news/2008/07/virginia-tech-building-supercomputer-out-of-324-mac-pros.ars) to the 2.93GHz Nehalem Mac Pros?

Feel free to run [SLB/Memhammer](http://kevinclosson.wordpress.com/2007/01/30/oracle-on-opteron-with-linux-the-numa-angle-part-iii) on your system and put the results in a comment.
