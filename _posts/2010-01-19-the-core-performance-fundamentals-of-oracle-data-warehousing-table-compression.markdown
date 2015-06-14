---
author: Greg Rahn
comments: true
date: 2010-01-19T12:00:55.000Z
layout: post
slug: the-core-performance-fundamentals-of-oracle-data-warehousing-table-compression
title: The Core Performance Fundamentals Of Oracle Data Warehousing - Table Compression
wp_id: 787
wp_categories:
  - Data Warehousing
  - Oracle
  - Performance
  - VLDB
wp_tags:
  - compression
  - data warehouse
  - Oracle
---

[back to [Introduction](/2009/12/14/the-core-performance-fundamentals-of-oracle-data-warehousing-introduction/)] Editor's note: This blog post does not cover [Exadata Hybrid Columnar Compression](http://www.oracle.com/technology/products/bi/db/exadata/pdf/ehcc_twp.pdf).

The first thing that comes to most people's mind when database table compression is mentioned is the savings it yields in terms of disk _space_.  While reducing the footprint of data on disk is relevant, I would argue it is the lesser of the benefits for data warehouses.  Disk capacity is very cheap and generally plentiful, however, disk bandwidth (scan speed) is proportional to the number of spindles, no mater what the disk capacity and thus is more expensive.  Table compression reduces the footprint on the disk drives that a given data set occupies so the amount of physical data that must be read off the disk platters is reduced when compared to the uncompressed version.  For example, if 4000 GB of raw data can compress to 1000 GB, it can be read off the same disk drives 4X as fast because it is reading and transferring 1/4 of the data off the spindles (relative to the uncompressed size).  Likewise, table compression allows for the database buffer cache to contain more data without having to increase the memory allocation because more rows can be stored in a compressed block/page compared to an uncompressed block/page.

Row major table compression comes in two flavors with the Oracle database: BASIC and OLTP.  In 11.1 these were also known by the key phrases `COMPRESS` or `COMPRESS FOR DIRECT_LOAD OPERATIONS` and `COMPRESS FOR ALL OPERATIONS`.  The `BASIC/DIRECT_LOAD` compression has been part of the Oracle database since version 9 and ˚ compression was introduced in 11.1 with the Advanced Compression option.

Oracle row major table compression works by storing the column values for a given block in a symbol table at the beginning of the block. The more repeated values per block, even across columns, the better the compression ratio. Sorting data can increase the compression ratio as ordering the data will generally allow more repeat values per block. Specific compression ratios and gains from sorting data are very data dependent but compression ratios are generally between 2x and 4x.

Compression does add some CPU overhead when direct path loading data, but there is no measurable performance overhead when reading data as the Oracle database can operate on compressed blocks directly without having to first uncompress the block.  The additional CPU required when bulk loading data is generally well worth the down wind gains for data warehouses.  This is because most data in a well designed data warehouse is write once, read many times.  Insert only and infrequently modified tables are ideal candidates for `BASIC` compression.  If the tables have significant DML performed against them, then OLTP compression would be advised (or no compression).

Given that most Oracle data warehouses that I have seen are constrained by I/O bandwidth (see [Balanced Hardware Configuration](/2009/12/22/the-core-performance-fundamentals-of-oracle-data-warehousing-balanced-hardware-configuration/)) it is highly recommended to leverage compression so the logical table scan rate can increase proportionally to the compression ratio.  This will result in faster table and partition scans on the same hardware.

### Oracle Documentation References:

- [Performance Tuning Guide: Table Compression](http://download.oracle.com/docs/cd/E11882_01/server.112/e10821/build_db.htm#i16118)
- [VLDB and Partitioning Guide: Partitioning and Table Compression](http://download.oracle.com/docs/cd/E11882_01/server.112/e10837/part_avail.htm#VLDBG00404)
- [Guidelines for Managing Tables: Consider Using Table Compression ](http://download.oracle.com/docs/cd/E11882_01/server.112/e10595/tables002.htm#ADMIN11630)
- [Table Compression in Oracle9i Release 2: A Performance Analysis](/files/orcl/o9ir2_compression_performance_twp.pdf)
- [Table Compression in Oracle Database 10g Release 2](http://www.oracle.com/technetwork/database/options/partitioning/twp-data-compression-10gr2-0505-128172.pdf)
- [Advanced Compression with Oracle Database 11g Release 2](http://www.oracle.com/technetwork/database/features/storage/advanced-compression-whitepaper-130502.pdf)
