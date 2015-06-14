---
author: Greg Rahn
comments: true
date: 2010-04-23T16:00:33.000Z
layout: post
slug: the-core-performance-fundamentals-of-oracle-data-warehousing-data-loading
title: The Core Performance Fundamentals Of Oracle Data Warehousing - Data Loading
wp_id: 878
wp_categories:
  - Data Warehousing
  - Oracle
  - VLDB
wp_tags:
  - data loading
  - external tables
  - 'sql*loader'
  - sqlldr
---

[back to [Introduction](/2009/12/14/the-core-performance-fundamentals-of-oracle-data-warehousing-introduction/)]

Getting flat file data into your Oracle data warehouse is likely a daily (or more possibly frequent) task, but it certainly does not have to be a difficult one.  Bulk loading data rates are governed by the following operations and hardware resources:

1. How fast can the data be read
2. How fast can data be written out
3. How much CPU power is available

I'm always a bit amazed (and depressed) when I hear people complain that their data loading rates are slow and they proceed to tell me things like:

- The source files reside on a shared NFS filer (or similar) and it has just a single GbE (1 Gigabit Ethernet) network path to the Oracle database host(s).
- The source files reside on this internal disk volume which consists of a two disk mirror (or a volume with very few spindles).

Maybe it's not entirely obvious so let me spell it out (as I did in [this tweet](http://twitter.com/GregRahn/status/8080583734)):

> One can not load data into a database faster than it can be delivered from the source. Database systems must obey the laws of physics!

Or putting it another way: Don't fall victim to slow data loading because of a slow performing data source.

Given a system that can provide data at fast enough rates, the loading rate becomes a factor of point #2 and #3. The database operations can be simplified to:

1. Read lines from flat files
2. Process lines into columns, internal data types and optionally compress
3. Write rows/columns out to disk

In most cases a reasonably size system becomes CPU bound, not write bound, on data loads as almost all Oracle data warehouses use compression which increases CPU consumption but reduces the IO requirement for the writes.  Or putting it another way:  Bulk loading into a compressed table should be a CPU bound operation, not a disk (write) bound operation.

### Data Loading Best Practices (What To Do and Why To Do It)

Oracle offers two methods to load data from flat files: 

1. [SQL*Loader](http://download.oracle.com/docs/cd/E14072_01/server.112/e10701/ldr_params.htmand)
2. [External Tables](http://download.oracle.com/docs/cd/E11882_01/server.112/e10595/tables013.htm#ADMIN12896)

I would _highly_ recommend that bulk loads (especially PDML loads) be done via External Tables and SQL\*Loader only be used for non-parallel loads (`PARALLEL=false`) with small amounts of data (not bulk loads).  The high level reason for this recommendation is that External Tables have nearly all the SQL functionality of a heap table and allow numerous more optimizations than SQL_Loader does and there are some undesirable side effects (mostly in the space management layer) from using `PARALLEL=true` with SQL\*Loader.

In order to avoid the reading of the flat files being the bottleneck, use a filesystem that is backed by numerous spindles (more than enough to provide the desired loading rate) and consider using compressed files in conjunction with the [external table preprocessor](/2008/11/19/preprocessor-for-external-tables/).  Using the preprocessor is especially useful if  there are proportionally more CPU resources on the database system than network or disk bandwidth because the use of compression on the source files allows for a larger logical row "delivery" for a given file size.  Something that may not be obvious either is to put the flat files on a filesystem that is mounted using directio mount options.  This will eliminate the file system cache being flooded with data that will (likely) never be read again (how many times do you load the same files?).  Another option that becomes available with Oracle 11.2 is [DBFS (database filesystem)](http://download.oracle.com/docs/cd/E14072_01/appdev.112/e10645/adlob_fs.htm) and is what is frequently used with the Oracle Database Machines & Exadata which is a fast and scalable solution for staging flat files.

In order to achieve the best loading speeds be sure to:

- Use External Tables
- Use a staging filesystem (and network) fast enough to meet your loading speed requirements (and consider directio mount options)
- Use Parallel Execution (parallel CTAS or PDML INSERT)
- Use [direct-path loads](http://download.oracle.com/docs/cd/E11882_01/server.112/e10595/tables004.htm#i1009100) (nologging CTAS or `INSERT /* +APPEND /`)
- Use a large enough initial/next extent size (8MB is usually enough)

If you follow these basic recommendations you should be able to achieve loading speeds that easily meet your requirements (otherwise you likely just need more hardware).

### Loading Data At Ludicrous Speed

I've yet to come across a reasonably designed system that is capable of becoming write bound as systems simply either 1) do not have enough CPU to do so or 2) are unable to read the source flat files anywhere near fast enough to do so.  I have, however, conducted experiments to test write throughput of a [Sun Oracle Database Machine](http://www.oracle.com/database/database-machine.html) ([Exadata V2](http://www.oracle.com/us/products/database/exadata/index.htm)) by using flat files cached completely in the filesystem cache and referencing them numerous times in the External Table DDL. The results should be quite eye opening for many, especially those who think the Oracle database can not load data fast.  Loading into an uncompressed table, I was able load just over 1TB of flat file data (over 7.8 billion rows) in a mear 4.6 minutes (275 seconds).  This experiment _does not_ represent typical loading speed rates as it's unlikely the source files are on a filesystem as fast as main memory, but it does demonstrate that if the flat file data could be delivered at such rates, the Oracle software and hardware can easily load it at close to physics speed (the max speed the hardware is capable of).

```sql
SQL> create table fastload
  2  pctfree 0
  3  parallel
  4  nologging
  5  nocompress
  6  storage(initial 8m next 8m)
  7  tablespace ts_smallfile
  8  as
  9  select * from et_fastload;

Table created.

Elapsed: 00:04:35.49

SQL> select count(*) from fastload;

     COUNT(*)
-------------
7,874,466,950

Elapsed: 00:01:06.54

SQL> select ceil(sum(bytes)/1024/1024) mb from user_segments where segment_name='FASTLOAD';

       MB
---------
1,058,750

SQL> exec dbms_stats.gather_table_stats(user,'FASTLOAD');

PL/SQL procedure successfully completed.

SQL> select num_rows,blocks,avg_row_len from user_tables where table_name='FASTLOAD';

  NUM_ROWS     BLOCKS AVG_ROW_LEN
---------- ---------- -----------
7874466950  135520008         133
```

Just so you don't think I'm making this stuff up, check out the [SQL Monitor Report](/assets/fastload_sqlmon.html) for the execution, noting the IO throughput graph from the Metrics tab (10GB/s write throughput isn't half bad).

So as you can see, flat file data loading has really become more of a data _delivery_ problem rather than a data _loading_ problem.  If the Oracle Database, specifically the Exadata powered Oracle Database Machine, can bulk load data from an external table whose files reside in the filesystem cache at a rate of 13TB per hour (give or take), you probably don't have to worry too much about meeting your data loading rate business requirements (wink).

Note: Loading rates will vary slightly depending on table definition, number of columns, data types, compression type, etc.

### References

- [Oracle Database Utilities - SQL*Loader Concepts](http://download.oracle.com/docs/cd/E11882_01/server.112/e10701/ldr_concepts.htm)
- [Oracle Database Concepts - External Tables](http://download.oracle.com/docs/cd/E11882_01/server.112/e10713/tablecls.htm#CNCPT1141)
- [Oracle Database Administrator's Guide -  Managing External Tables (including Preprocessing External Tables)](http://download.oracle.com/docs/cd/E11882_01/server.112/e10595/tables013.htm)
- [Oracle Database Administrator's Guide  - Loading Tables](http://download.oracle.com/docs/cd/E11882_01/server.112/e10595/tables004.htm)
- [Oracle Database File System](http://download.oracle.com/docs/cd/E14072_01/appdev.112/e10645/adlob_fs.htm)
