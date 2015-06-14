---
author: Greg Rahn
comments: true
date: 2010-09-27
layout: post
slug: oracle-exadata-database-machine-offerings-x2-2-and-x2-8
title: 'Oracle Exadata Database Machine Offerings: X2-2 and X2-8'
wp_id: 1170
wp_categories:
  - Exadata
  - Oracle
wp_tags:
  - Exadata
  - Exadata Database Machine
  - X2-2
  - X2-8
---

For those who followed or attended Oracle OpenWorld last week you may have seen the introduction of the new hardware for the [Oracle Exadata Database Machine](http://www.oracle.com/us/products/database/database-machine/index.html). Here's a high level summary of what was introduced:

- Updated Exadata Storage Server nodes (based on the [Sun Fire X4270 M2](http://www.oracle.com/us/products/servers-storage/servers/x86/sun-fire-x4270-m2-server-077279.html))
- Updated 2 socket 12 core database nodes for the X2-2 (based on the [Sun Fire X4170 M2](http://www.oracle.com/us/products/servers-storage/servers/x86/sun-fire-x4170-m2-server-077278.html))
- New offering of 8 socket 64 core database nodes using the Intel 7500 Series (Nehalem-EX) processors for the X2-8 (based on the [Sun Fire X4800](http://www.oracle.com/us/products/servers-storage/servers/x86/sun-fire-x4800-server-077287.html))

The major updates in the X2-2 compared to V2 database nodes are:

- CPUs updated from quad-core Intel 5500 Series (Nehalem-EP) processors to six-core Intel 5600 Series (Westmere-EP)
- Network updated from 1 GbE to 10 GbE
- RAM updated from 72 GB to 96 GB

The updates to the Exadata Storage Servers (which are identical for both the X2-2 and X2-8 configurations) are:

- CPUs updated to the six-core Intel 5600 Series (Westmere-EP) processors
- 600 GB 15k RPM SAS offering now known as HP (High Performance)
- 2 TB  7.2k RPM SAS offering now known as HC (High Capacity) [previously the 2 TB drives were 7.2k RPM SATA]

One of the big advantages of the CPU updates to the Intel 5600 Series (Westmere-EP) processors is that the Oracle Database Transparent Data Encryption can leverage the Intel Advanced Encryption Standard New Instructions ([Intel AES-NI](http://software.intel.com/en-us/articles/intel-advanced-encryption-standard-aes-instructions-set/)) found in the Intel Integrated Performance Primitives ([Intel IPP](http://software.intel.com/en-us/intel-ipp/)).  This "in silicon" functionality results in a 10x increase in encryption and an 8x increase in decryption using 256 bit keys per the [Oracle Press release](http://www.oracle.com/us/corporate/press/173758).

The differences (as I quickly see) between the X2-2 and the X2-8 offerings are:

- X2-8 only comes in full racks (of 2 database nodes)
- X2-8 has 2 TB of RAM per rack (compared to 768 GB for the X2-2)
- X2-8 has 16s/128c/256t per rack vs. 16s/96c/192t for the X2-2 (s=sockets, c=cores, t=threads)

One of the other Exadata related announcements was that Solaris x86 will be an option for the database OS in addition to Linux.

In summary, the Oracle Exadata Database Machine is riding the wave of Intel processors and is leveraging the Intel IPP functionality and will likely do so for the foreseeable future.

If you want all hardware details, check out the product data sheets:

- [Oracle Exadata Database Machine X2-8](http://www.oracle.com/technetwork/database/exadata/dbmachine-x2-8-datasheet-173705.pdf)
- [Oracle Exadata Database Machine X2-2](http://www.oracle.com/technetwork/database/exadata/dbmachine-x2-2-datasheet-175280.pdf)
- [Oracle Exadata Storage Servers](http://www.oracle.com/technetwork/database/exadata/exadata-datasheet-1-129084.pdf)

I just noticed that Alex Gorbachev has a nice [table format of the hardware components](http://www.pythian.com/news/17071/oracle-exadata-database-machine-x2-8-x2-2/) for your viewing pleasure as well.
