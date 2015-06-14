---
author: Greg Rahn
comments: true
date: 2008-09-08T08:50:40.000Z
layout: post
slug: understanding-performance
title: Understanding Performance
wp_id: 88
wp_categories:
  - Oracle
  - Performance
  - Troubleshooting
wp_tags:
  - assm
  - block size
  - bug 6918210
  - dtrace
  - pctfree
  - pstack
---

There has been some debate in forumsphere/blogosphere centered around [Steve Karam's](http://www.oraclealchemist.com/) observation of a [20x elapsed time difference](http://forums.oracle.com/forums/message.jspa?messageID=2589212#2589212) in an update statement "by only changing the block size". At this point in time, it is pretty much understood (I hope) that this performance delta is directly related to bug 6918210. This bug manifests its nasty head when the following conditions exist:

- table in an ASSM tablespace
- 16KB or 32KB block size
- row migrations at the ASSM storage layer

You might ask what are "**row migrations**"? Row migrations are generally caused by too low of a `PCTFREE` setting on the table. When row has grown in length due to an UPDATE and no longer fits in the current block it is migrated to a new block in which there is enough space for it. This migration is an insert followed by an delete at the storage layer.

[Jonathan Lewis](http://jonathanlewis.wordpress.com/) gets the credit for putting [the test case](http://forums.oracle.com/forums/message.jspa?messageID=2592642#2592642) ([alt. URL](/assets/jl_test_case.html)) together that reproduces performance bug. Since then I've run the test case numerous times, with some slight modifications, but I would like to note directly some results that I observed by modifying PCTFREE. These tests were executed on 10.2.0.4 using 200,000 rows vs. the 830,000 rows that the original test case contains. The reason for that is I could produce the scenarios I wanted and I didn't have to wait for hours when the bug was present.

BLOCK SIZE | PCT_FREE | BLOCKS (BEFORE/AFTER) | BYTES (BEFORE/AFTER) | AVG_ROW_LEN (BEFORE/AFTER) | UPDATE TIME
--- | --- | --- | --- | --- | --- | ---
4096  | 10 | 742 / 2758 | 3,039,232 / 11,296,768 | 5 / 11 | 00:00:26.71
4096  | 35 | 994 / 994  | 4,071,424 / 4,071,424  | 5 / 11 | 00:00:08.09
8192  | 10 | 370 / 1378 | 3,031,040 / 11,288,576 | 5 / 11 | 00:00:27.36
8192  | 35 | 496 / 496  | 4,063,232 / 4,063,232  | 5 / 11 | 00:00:08.99
16384 | 10 | 184 / 814  | 3,014,656 / 13,336,576 | 5 / 11 | 00:10:59.95
16384 | 35 | 247 / 247  | 4,049,318 / 4,049,318  | 5 / 11 | 00:00:08.81

In Steve's case, he started with a 16KB block and a default `PCTFREE` setting of 10 (he has not noted otherwise). Because the test case consists of a two column table where the second column starts out NULL and then is updated to the first column's value, the default `PCTFREE` setting is not optimal. As you can see from the table, with a value of `PCTFREE 10`, quite a few row migrations take place. This is evident by the increase of the number of blocks in the table. Notice that when `PCTFREE 35` is used, the number of blocks does not change. This is because the row can be expanded in length (in place) and thus no row migrations take place. It is also worth noting that when row migrations take place, the table grows in size to around 4x the original size. Most importantly, performance is best when `PCTFREE` is optimal, no matter what the block size.

### Does Block Size Matter?

In this case block size matters when bug 6918210 is encountered, but what really matters is an appropriate setting of `PCTFREE`. As the metrics demonstrate, performance is equal between each of the three block sizes and a given `PCTFREE` setting, the exception being the bug. Performance is best with an optimal `PCTFREE` setting, no matter what the block size.

### How Would One Have Discovered This Was A Bug?

First and foremost, when drastic performance deltas are observed, they should be throughly investigated. If it is too good to be true, it probably is. Because this bug is in the ASSM layer it is difficult to diagnose. This is because that layer does not contain the same level of instrumentation that other layers do. Even if you look at the 10046 trace or the ASH data, it will not provide sufficient information. So what does one do in this case? Well, if you can not get debug info from inside the database, then you have to look outside. Specifically, getting a stack trace using [`pstack`](http://www.linuxcommand.org/man_pages/pstack1.html). When the 16KB/PCTFREE 10 update was running I took some stack traces. What I noticed was this:

```
$ pstack 23233
#0  0x09ed3e26 in kdb_count_pdml_itl ()
#1  0x09ed42ad in kdb_diff_pdml_itl ()
#2  0x09ef02a7 in kdt_bseg_srch_cbk ()
#3  0x089d2ddd in ktspfpblk ()
#4  0x089d32b9 in ktspfsrch ()
#5  0x089ce530 in ktspscan_bmb ()
#6  0x089ccff0 in ktspgsp_cbk1 ()
#7  0x089cd612 in ktspgsp_cbk ()
#8  0x09ef2946 in kdtgsp ()
#9  0x09ef0f61 in kdtgrs ()
#10 0x09ee848b in kdtInsRow ()
#11 0x09ea724b in kdumrp ()
#12 0x09ea35f0 in kduurp ()
#13 0x09e96dd0 in kdusru ()
#14 0x095b4ad4 in updrowFastPath ()
#15 0x0a1eb0f4 in __PGOSF287_qerupFRowProcedure ()
#16 0x0a1eb7d0 in qerupFetch ()
#17 0x0a215c26 in qerstFetch ()
#18 0x095a42b4 in updaul ()
#19 0x095a6aa3 in updThreePhaseExe ()
#20 0x095a594f in updexe ()
#21 0x0a3c68f1 in opiexe ()
#22 0x0a4cd1db in kpoal8 ()
#23 0x08cd5138 in opiodr ()
#24 0x0acdb78d in ttcpip ()
#25 0x08cd1212 in opitsk ()
#26 0x08cd3d51 in opiino ()
#27 0x08cd5138 in opiodr ()
#28 0x08cca5f2 in opidrv ()
#29 0x0962f797 in sou2o ()
#30 0x08299b3b in opimai_real ()
#31 0x08299a2b in main ()
```

I would not expect anyone to know what these function do, but some might have some guesses based on parts of the names. While that may be useful, it is not necessary. What is important is that this stack trace was identical for nearly the entire 11 minutes that 16KB/PCTFREE 10 update ran. **The most important part of performance troubleshooting is gathering good information**.  Even if you do not know how to exactly interpret it, it is likely that someone in Oracle Support can.

Now for those of you who are really paying attention, you may notice that the two functions (`ktspscan_bmb` & `ktspfsrch`) that [Jonathan lists in his key statistics](http://forums.oracle.com/forums/message.jspa?messageID=2592642#2592642) are in this stack trace. This is not just coincidence.

### Troubleshoot Like A Real Expert

One of the guys who frequently uses (and blogs about) this type of performance troubleshooting approach is [Tanel Poder](http://blog.tanelpoder.com). I would have really liked to try out his [DTrace script](http://blog.tanelpoder.com/files/scripts/dtrace/dstackprof.sh) but I did not have a Solaris host readily available, so I was stuck with old unsexy `pstack` on Linux. This brings me to an awesome quote from his [recent blog post using DTrace](http://blog.tanelpoder.com/2008/09/02/oracle-hidden-costs-revealed-part2-using-dtrace-to-find-why-writes-in-system-tablespace-are-slower-than-in-others/):

> ...the key point of this article is that I could have started guessing or setting various events or undocumented parameters for probing Oracle here and there, for figuring out what’s going on. But I used a simple systematic approach instead. When Oracle Wait Interface and V$SESSTAT counters didn’t help, looked into process stack next... And if I hadn’t figured out the cause myself, I would have had some solid evidence for support.

I can not stress enough how important the approach matters. People who follow this approach will ultimately be successful and also much better off than those who just hack away. Understanding the **why** of performance is key.
