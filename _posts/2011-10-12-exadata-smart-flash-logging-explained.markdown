---
author: Greg Rahn
comments: true
date: 2011-10-12T22:05:36.000Z
layout: post
slug: exadata-smart-flash-logging-explained
title: Exadata Smart Flash Logging Explained
wp_id: 1550
wp_categories:
  - 11gR2
  - Exadata
  - OLTP
  - Oracle
  - Performance
wp_tags:
  - Exadata
  - Exadata Smart Flash Logging
---

I've seen some posts on the blogosphere where people attempt to explain (or should I say guess) how Exadata Smart Flash Logging works and most of them are wrong.  Hopefully this post will help clear up some the misconceptions out there.

The following is an excerpt from the paper entitled "[Exadata Smart Flash Cache Features and the Oracle Exadata Database Machine](http://www.oracle.com/technetwork/database/exadata/exadata-smart-flash-cache-366203.pdf)" that goes into technical detail on the Exadata Smart Flash Logging feature.

> Smart Flash Logging works as follows. When receiving a redo log write request, Exadata will do 
> parallel writes to the on-disk redo logs as well as a small amount of space reserved in the flash 
> hardware. When either of these writes has successfully completed the database will be 
> immediately notified of completion. If the disk drives hosting the logs experience slow response 
> times, then the Exadata Smart Flash Cache will provide a faster log write response time. 
> Conversely, if the Exadata Smart Flash Cache is temporarily experiencing slow response times 
> (e.g., due to wear leveling algorithms), then the disk drive will provide a faster response time. 
> Given the speed advantage the Exadata flash hardware has over disk drives, log writes should be 
> written to Exadata Smart Flash Cache, almost all of the time, resulting in very fast redo write 
> performance. This algorithm will significantly smooth out redo write response times and provide 
> overall better database performance. 
> 
> The Exadata Smart Flash Cache is not used as a permanent store for redo data – it is just a 
> temporary store for the purpose of providing fast redo write response time. The Exadata Smart 
> Flash Cache is a cache for storing redo data until this data is safely written to disk. The Exadata 
> Storage Server comes with a substantial amount of flash storage. A small amount is allocated for 
> database logging and the remainder will be used for caching user data. The best practices and 
> configuration of redo log sizing, duplexing and mirroring do not change when using Exadata 
> Smart Flash Logging. Smart Flash Logging handles all crash and recovery scenarios without 
> requiring any additional or special administrator intervention beyond what would normally be 
> needed for recovery of the database from redo logs. From an end user perspective, the system 
> behaves in a completely transparent manner and the user need not be aware that flash is being 
> used as a temporary store for redo. The only behavioral difference will be consistently low 
> latencies for redo log writes. 
> 
> By default, 512 MB of the Exadata flash is allocated to Smart Flash Logging. Relative to the 384 
> GB of flash in each Exadata cell this is an insignificant investment for a huge performance 
> benefit. This default allocation will be sufficient for most situations. Statistics are maintained to 
> indicate the number and frequency of redo writes serviced by flash and those that could not be 
> serviced, due to, for example, insufficient flash space being allocated for Smart Flash Logging. 
> For a database with a high redo generation rate, or when many databases are consolidated on to 
> one Exadata Database Machine, the size of the flash allocated to Smart Flash Logging may need 
> to be enlarged. In addition, for consolidated deployments, the Exadata I/O Resource Manager 
> (IORM) has been enhanced to enable or disable Smart Flash Logging for the different databases 
> running on the Database Machine, reserving flash for the most performance critical databases. 


