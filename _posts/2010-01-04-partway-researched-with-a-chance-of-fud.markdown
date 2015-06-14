---
author: Greg Rahn
comments: true
date: 2010-01-04T12:00:21.000Z
layout: post
slug: partway-researched-with-a-chance-of-fud
title: Partway Researched With A Chance Of FUD
wp_id: 708
wp_categories:
  - Exadata
  - Oracle
wp_tags:
  - Exadata
  - FUD
  - ParAccel
---

I tend to keep the content of this blog fairly technical and engineering focused, but every now and then I have to venture off and do an editorial post.  Recently some of the ParAccel management decided to fire up the [FUD](http://en.wikipedia.org/wiki/Fear,_uncertainty_and_doubt) machine on the [ParAccel blog](http://paraccel.com/data_warehouse_blog/?p=156) and take aim at Oracle's Exadata making the following claims:

> There are 12 SAS disks in the storage server with a speed of about 75 MB/s [The SUN Oracle Exadata Storage Server datasheet claims 125 MB/s but we think that is far-fetched.]" -Rick Glick, Vice President of Technology and Architecture ([link](http://paraccel.com/data_warehouse_blog/?p=156&cpage=1#comment-457))

> We stand by the 75MB/sec as a conservative, reliable number. We see higher numbers in disk tests, but never anywhere near 125MB/sec." -Barry Zane, Chief Technology Officer ([link](http://paraccel.com/data_warehouse_blog/?p=156&cpage=1#comment-460))

### Far Fetched Or Fact?

As a database performance engineer, I strive to be extremely detailed and well researched with my work.  Clearly, these comments from Rick and Barry were not well researched as is evident from information publicly available on the Internet.

The first bit of documentation I would research before making such comments would be the hard disk drive specification sheet.  The 12 drives in the [Exadata Storage Server](http://www.oracle.com/us/products/database/exadata/index.htm), a [Sun Fire X4275](http://www.sun.com/servers/x64/x4275/), are 3.5-inch 15K RPM SAS 2.0 6Gb/sec 600GB drives.  Looking at the [drive spec sheet](http://dlc.sun.com/pdf/820-7290-10/820-7290-10.pdf), it clearly states that the sustained sequential read is 122 MB/sec (at ID) to 204 MB/sec (at OD) [that's Inner Diameter & Outer Diameter].  Seems to me that Oracle's claim of 1500MB/s per Exadata Storage Server (125MB/s for each of the 12 SAS drives) is certainly between 122MB/s and 204MB/s.

Now granted, one might think that vendors overstate their performance claims, so it may be resourceful to search the Internet for some third party evaluation of this hard disk.  I went to a fairly well known Internet search engine to try find more information using a [highly sophisticated and complex set of search keywords](http://lmgtfy.com/?q=SAS+2.0+6Gb%2Fs+600GB+hard+disk+performance).  To my astonishment, there at the top of the search results page was [a write up by a third party](http://www.tweaktown.com/reviews/2993/seagate_cheetah_15k_7_sas_2_0_6gb_s_600gb_hard_disk/index.html).  I would encourage reading the entire article, but if you want to just skip to [page 5 [Benchmarks - HD Tune Pro]](http://www.tweaktown.com/reviews/2993/seagate_cheetah_15k_7_sas_2_0_6gb_s_600gb_hard_disk/index5.html) you will be presented with data that shows the minimum (120MB/s), average (167MB/s) and maximum (200MB/s) read throughput for sequential read tests performed by the author for the hard disk drive in dispute.  Looks to me that those numbers are completely in line with the Sun spec sheet - no over exaggeration going on here.  At this point there should be exactly zero doubt that the drives themselves, with the proper SAS controller, are easily physically capable of 125MB/s read rates and more.

### Stand By Or Sit Down?

Interestingly enough, after both [I comment](http://paraccel.com/data_warehouse_blog/?p=156&cpage=1#comment-463) and [Kevin Closson comment](http://paraccel.com/data_warehouse_blog/?p=156&cpage=1#comment-461), calling out this ill researched assertion on the physics of HDDs, [Barry Zane then responds](http://paraccel.com/data_warehouse_blog/?p=156&cpage=1#comment-620):

> As I see it, there are three possibilities:
> 
>   1. Disk vendors are overly optimistic in their continuous sequential read rates.
>   2. The newer class of SAS2 compatible 15Krpm drives and controllers are faster than the older generation we’ve measured.
>   3. Our disk access patterns are not getting all the available performance.

Let's drill into each of these possibilities:

1. Perhaps vendors _are_ overly optimistic, but how overly optimistic could they possibly be?  I mean, really, 125MB/s is easily between the spec sheet rates of 122MB/s and 204MB/s.  Truly 75MB/s is a low ball number for these drives. Even Exadata V1 SAS drives more than 75MB/s per drive and the HDD is not the limiting factor in the scan throughput (a good understanding of the hardware components should lead you to what is).  Even the [Western Digital 300GB 10K RPM VelociRaptor](http://www.wdc.com/en/products/products.asp?DriveID=459) disk drive has [benchmarks](http://benchmarkreviews.com/index.php?option=com_content&task=view&id=278&Itemid=60&limit=1&limitstart=9) that show a maximum sequential data transfer rate of more than 120 MB/s and sustain a minimum of 75MB/s even on the innermost part of the platter, and that is a SATA drive commonly used in PCs!
2. Barry states that ParAccel has no experience nor metrics (measurements) with these drives or seemingly any drives like them, but yet Barry calls "75MB/sec as a conservative, reliable number".  Just how reliable of a number can it possibly be when you have exactly zero data points and zero experience with the HDDs in dispute?  Is this a debate that can be won by strength of personality or does it actually require data, numbers and facts?
3. Perhaps the ParAccel database has disk access patterns that can not drive the scan rates that Exadata can, but should one assert that because ParAccel database may not drive that IO rate, Exadata can't, even when said rate is within the realm of physical capability?  I certainly would think not.  Not unless the intention is simply to promote FUD.

So, as I see it, there are exactly two possibilities:  Either one has technical knowledge on what they are talking about (and they have actual data/facts to support it) or they do not and they are just making things up.  At this point I think the answer is quite clear in this situation; Rick and Barry had no data to support their (incorrect) assertions.

### And The Truth Shall Be Revealed

Three weeks after Barry's "three possibilities" comment, [Barry reveals the real truth](http://paraccel.com/data_warehouse_blog/?p=156&cpage=1#comment-850):

> ...we [ParAccel] have gotten a number of newer servers with SAS2 drives...[and] the newer generation of disk drives are faster than my experience...Exadata’s claim of 1500MB/sec per server seems completely reasonable...My apologies for any confusion created.

As it has come to pass, my assertion that ParAccel had absolutely no experience and thus no data to support their claims is validated (not that I really had any doubts).  Spreading FUD generally does cause unnecessary confusion, but then again, that is usually the intention.  I would expect such nonsense from folks with _marketing_ in their title, but I hold a higher bar for people with _technology_ in their titles.  This was a simple debate about physical disk drive characteristics (and not software) and that is something _anyone_ could get concrete factual data on (assuming they actually take the time and effort).

### And Isn't It Ironic... Don't You Think?

The same day I read Barry's "truth comment" I also read Jerome Pineau's [blog post on social media marketing](http://jeromepineau.blogspot.com/2009/12/social-media-marketing-101-new-fountain.html).  I could not help but recognize (and laugh about) the irony of the situation.  Jerome lists several tips on being successful in SMM and the first two really stood out to me:

1. Do not profess expertise on topics you know little about. Eventually, it will show.
2. Always remain honest. Never lie. Your most important asset is credibility. You can fix almost any mistake except credibility damage.

Truly, truly ironic...
