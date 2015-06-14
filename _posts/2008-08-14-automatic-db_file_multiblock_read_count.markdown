---
author: Greg Rahn
comments: true
date: 2008-08-14T12:00:39.000Z
layout: post
slug: automatic-db_file_multiblock_read_count
title: Automatic DB_FILE_MULTIBLOCK_READ_COUNT
wp_id: 76
wp_categories:
  - 11gR1
  - Data Warehousing
  - Execution Plans
  - Optimizer
  - Oracle
  - Performance
  - SQL Tuning
  - Statistics
wp_tags:
  - Automatic DB_FILE_MULTIBLOCK_READ_COUNT
  - block size
---

_Note: Originally this experiment was from [a post I wrote](http://forums.oracle.com/forums/message.jspa?messageID= 2568081#2568081) on the [Oracle Forum: Database - General](http://forums.oracle.com/forums/forum.jspa?forumID=61&start=0).   I recommend that you read [Jonathan Lewis' summarization](http://jonathanlewis.wordpress.com/2008/07/19/block-sizes/) of the thread instead of reading all 671 posts (as of today).  You will spend much less time and get more out of the discussion._

One of the new features that was released in 10gR2 is the automatic `DB_FILE_MULTIBLOCK_READ_COUNT`.  Below are portions from the documentation that describe this feature.

[Oracle Database 10g New Features](http://download.oracle.com/docs/cd/B19306_01/server.102/b14214/chapter1.htm#FEATURENO05506)

>The `DB_FILE_MULTIBLOCK_READ_COUNT` parameter controls the amount of block prefetching done in the buffer cache during scan operations, such as full table scan and index fast full scan. The value of this parameter can have a significant impact on the overall database performance. This feature enables Oracle Database to automatically select the appropriate value for this parameter depending on the operating system optimal I/O size and the size of the buffer cache.

>This feature simplifies manageability by automating the tuning of `DB_FILE_MULTIBLOCK_READ_COUNT` initialization parameter.

[Oracle Database Performance Tuning Guide](http://download.oracle.com/docs/cd/B19306_01/server.102/b14211/optimops.htm#PFGRF10108)

> This parameter specifies the number of blocks that are read in a single I/O during a full table scan or index fast full scan. The optimizer uses the value of `DB_FILE_MULTIBLOCK_READ_COUNT` to cost full table scans and index fast full scans. Larger values result in a cheaper cost for full table scans and can result in the optimizer choosing a full table scan over an index scan. If this parameter is not set explicitly (or is set is 0), the optimizer will use a default value of 8 when costing full table scans and index fast full scans.

### Be Aware of the Bug

Although [the documentation states](http://download-west.oracle.com/docs/cd/B19306_01/server.102/b14211/iodesign.htm#i28412):

>If this value is not set explicitly (or is set to 0)...

there is a bug (5768025) if one sets `DB_FILE_MULTIBLOCK_READ_COUNT` to 0.  This will result in making all muti-block I/O requests 1 block (db file sequential read), thus completely disabling the advantage of `DB_FILE_MULTIBLOCK_READ_COUNT`.  Be aware!!!  My recommendation: just don't set it if you want to enable it.

### Read I/O Request Size

Currently, the maximum read I/O request size that Oracle can issue to the OS is 1 Megabyte (1MB).  The equation for the maximum read I/O request size from the Oracle database is `db_file_multiblock_read_count * db_block_size`.  For example, if you are using a `db_block_size` of 8192 (8k) and `db_file_multiblock_read_count` is set to 64 the maximum read size request would be 8192 * 64 = 524,288 bytes or 0.5MB.  One could set `db_file_multiblock_read_count = 128` to achieve a 1MB read size, but that is the absolute maximum possible.

The advantage of using the automatic `DB_FILE_MULTIBLOCK_READ_COUNT` is that the database can leverage the benefits of a large read I/O request size without over influencing the cost based optimizer toward full table scans.

### The Experiment of Block Size and Automatic DB_FILE_MULTIBLOCK_READ_COUNT

The purpose of this experiment will be to provide metrics so we can answer the question: Does block size have any impact on elapsed time for a FTS query with 100% physical I/Os when using the automatic `DB_FILE_MULTIBLOCK_READ_COUNT`?

The experiment:

- 4 identical tables, with block sizes of 2k, 4k, 8k and 16k
- `DB_FILE_MULTIBLOCK_READ_COUNT` will be unset, letting the Oracle database choose the best size
- cold db cache so forcing 100% physical reads
- ASM storage, so no file system cache
- query will be: `select * from table;`

For the data in the table I'm going to use the WEB_RETURNS (SF=100GB) table from TPC-DS. The flat file is 1053529104 bytes (~1GB) as reported from the `ls` command.

```
-- tablespace create statements
create tablespace tpcds_8k  datafile '+GROUP1' size 1500m;
create tablespace tpcds_2k  datafile '+GROUP1' size 1500m blocksize 2k;
create tablespace tpcds_4k  datafile '+GROUP1' size 1500m blocksize 4k;
create tablespace tpcds_16k datafile '+GROUP1' size 1500m blocksize 16k;

-- table create statements
create table web_returns_8k  tablespace tpcds_8k  as select * from web_returns_et;
create table web_returns_2k  tablespace tpcds_2k  as select * from web_returns_et;
create table web_returns_4k  tablespace tpcds_4k  as select * from web_returns_et;
create table web_returns_16k tablespace tpcds_16k as select * from web_returns_et;

-- segment size
select segment_name, sum(bytes)/1024/1024 mb from user_segments group by segment_name;

SEGMENT_NAME                 MB
-------------------- ----------
WEB_RETURNS_2K              976
WEB_RETURNS_4K              920
WEB_RETURNS_8K              896
WEB_RETURNS_16K             880

SQL> desc WEB_RETURNS_16K
 Name                                      Null?    Type
 ----------------------------------------- -------- ----------------------------
 WR_RETURNED_DATE_SK                                NUMBER(38)
 WR_RETURNED_TIME_SK                                NUMBER(38)
 WR_ITEM_SK                                         NUMBER(38)
 WR_REFUNDED_CUSTOMER_SK                            NUMBER(38)
 WR_REFUNDED_CDEMO_SK                               NUMBER(38)
 WR_REFUNDED_HDEMO_SK                               NUMBER(38)
 WR_REFUNDED_ADDR_SK                                NUMBER(38)
 WR_RETURNING_CUSTOMER_SK                           NUMBER(38)
 WR_RETURNING_CDEMO_SK                              NUMBER(38)
 WR_RETURNING_HDEMO_SK                              NUMBER(38)
 WR_RETURNING_ADDR_SK                               NUMBER(38)
 WR_WEB_PAGE_SK                                     NUMBER(38)
 WR_REASON_SK                                       NUMBER(38)
 WR_ORDER_NUMBER                                    NUMBER(38)
 WR_RETURN_QUANTITY                                 NUMBER(38)
 WR_RETURN_AMT                                      NUMBER(7,2)
 WR_RETURN_TAX                                      NUMBER(7,2)
 WR_RETURN_AMT_INC_TAX                              NUMBER(7,2)
 WR_FEE                                             NUMBER(7,2)
 WR_RETURN_SHIP_COST                                NUMBER(7,2)
 WR_REFUNDED_CASH                                   NUMBER(7,2)
 WR_REVERSED_CHARGE                                 NUMBER(7,2)
 WR_ACCOUNT_CREDIT                                  NUMBER(7,2)
 WR_NET_LOSS                                        NUMBER(7,2)

```

I'm using a Pro\*C program to execute each query and fetch the rows with an array size of 100. This way I don't have to worry about spool space, or overhead of SQL\*Plus formatting. I have 4 files that contain the queries for each of the 4 tables for each of the 4 block sizes.

Output from a run is such:

```
BEGIN_TIMESTAMP   QUERY_FILE                       ELAPSED_SECONDS ROW_COUNT
----------------- -------------------------------- --------------- ---------
20080604 22:22:19 2.sql                                 125.696083   7197670
20080604 22:24:25 4.sql                                 125.439680   7197670
20080604 22:26:30 8.sql                                 125.502804   7197670
20080604 22:28:36 16.sql                                125.251398   7197670
```

As you can see, no matter what the block size, the execution time is the same (discounting fractions of a second).

### The TKPROF Output

Below is the TKPROF output from each of the 4 executions.

```
TKPROF: Release 11.1.0.6.0 - Production on Wed Jun 4 22:35:07 2008

Copyright (c) 1982, 2007, Oracle.  All rights reserved.

Trace file: v11_ora_12162.trc
Sort options: default

********************************************************************************
count    = number of times OCI procedure was executed
cpu      = cpu time in seconds executing
elapsed  = elapsed time in seconds executing
disk     = number of physical reads of buffers from disk
query    = number of buffers gotten for consistent read
current  = number of buffers gotten in current mode (usually for update)
rows     = number of rows processed by the fetch or execute call
********************************************************************************

/* 2.sql */

select * from web_returns_2k



call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch    71978     25.39      26.42     493333     560355          0     7197670
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total    71980     25.39      26.42     493333     560355          0     7197670

Misses in library cache during parse: 0
Optimizer mode: ALL_ROWS
Parsing user id: 50

Rows     Row Source Operation
-------  ---------------------------------------------------
7197670  TABLE ACCESS FULL WEB_RETURNS_2K (cr=560355 pr=493333 pw=493333 time=88067 us cost=96149 size=770150690 card=7197670)


Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                   71980        0.00          0.16
  SQL*Net message from client                 71980        0.00         93.20
  db file sequential read                         3        0.00          0.01
  direct path read                             1097        0.04          0.13
  SQL*Net more data to client                 71976        0.00          1.88
********************************************************************************

/* 4.sql */
select * from web_returns_4k

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        2      0.00       0.00          0          0          0           0
Execute      2      0.00       0.03          0          0          0           0
Fetch    71978     24.98      25.92     232603     302309          0     7197670
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total    71982     24.98      25.96     232603     302309          0     7197670

Misses in library cache during parse: 0
Parsing user id: 50

Rows     Row Source Operation
-------  ---------------------------------------------------
7197670  TABLE ACCESS FULL WEB_RETURNS_4K (cr=302309 pr=232603 pw=232603 time=84876 us cost=51644 size=770150690 card=7197670)


Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                   71981        0.00          0.15
  SQL*Net message from client                 71981        0.00         93.19
  db file sequential read                         2        0.00          0.01
  direct path read                             1034        0.02          0.19
  SQL*Net more data to client                 71976        0.00          1.85
  rdbms ipc reply                                 1        0.03          0.03
********************************************************************************

/* 8.sql */
select * from web_returns_8k

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        2      0.00       0.00          0          0          0           0
Execute      2      0.00       0.01          0          0          0           0
Fetch    71978     24.61      25.71     113157     183974          0     7197670
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total    71982     24.61      25.73     113157     183974          0     7197670

Misses in library cache during parse: 0
Parsing user id: 50

Rows     Row Source Operation
-------  ---------------------------------------------------
7197670  TABLE ACCESS FULL WEB_RETURNS_8K (cr=183974 pr=113157 pw=113157 time=85549 us cost=31263 size=770150690 card=7197670)


Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                   71981        0.00          0.15
  SQL*Net message from client                 71981        0.00         93.32
  db file sequential read                         1        0.01          0.01
  direct path read                              999        0.01          0.17
  SQL*Net more data to client                 71976        0.00          1.83
  rdbms ipc reply                                 1        0.01          0.01
********************************************************************************

/* 16.sql */
select * from web_returns_16k

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch    71978     24.74      25.59      55822     127217          0     7197670
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total    71980     24.74      25.59      55822     127217          0     7197670

Misses in library cache during parse: 0
Optimizer mode: ALL_ROWS
Parsing user id: 50

Rows     Row Source Operation
-------  ---------------------------------------------------
7197670  TABLE ACCESS FULL WEB_RETURNS_16K (cr=127217 pr=55822 pw=55822 time=82996 us cost=21480 size=770150690 card=7197670)


Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                   71980        0.00          0.15
  SQL*Net message from client                 71980        0.00         93.39
  db file sequential read                         1        0.00          0.00
  direct path read                              981        0.01          0.16
  SQL*Net more data to client                 71976        0.00          1.84
********************************************************************************
```

### Raw Trace File Metrics

```
select FILE_ID,TABLESPACE_NAME from dba_data_files where TABLESPACE_NAME like 'TPC%'

   FILE_ID TABLESPACE_NAME
---------- ---------------
    16 TPCDS_8K
    17 TPCDS_2K
    18 TPCDS_4K
    19 TPCDS_16K

2k: WAIT #2: nam='direct path read' ela= 37 file number=17 first dba=33280 block cnt=512 obj#=55839 tim=1212643347820647
4k: WAIT #2: nam='direct path read' ela= 33 file number=18 first dba=16640 block cnt=256 obj#=55840 tim=1212643474070675
8k: WAIT #1: nam='direct path read' ela= 30 file number=16 first dba=8320  block cnt=128 obj#=55838 tim=1212643599631927
16k:WAIT #2: nam='direct path read' ela= 39 file number=19 first dba=55040 block cnt=64  obj#=55841 tim=1212643838893785
```

The raw trace file shows us that for each block size the reads are optimized to 1MB. For example, with a 2k block, 512 blocks are read at a time. The `cnt=` is the number of blocks read with a single multi-block read.

Block Size | MBRC | I/O Size
--- | --- | ---
2,048 | 512 | 1MB
4,096 | 256 | 1MB
8,192 | 128 | 1MB
16,384 | 64 | 1MB


### So What Does This Experiment Demonstrate?

When using the automatic `DB_FILE_MULTIBLOCK_READ_COUNT`, it actually **is not the blocksize** that really matters, **but the I/O request size**. More importantly, the Oracle database can decide the optimal MBRC no matter what the blocksize, demonstrating there is no advantage to a larger (or even smaller) blocksize in this case.

Think of it like this: If I grab $100 from a bucket of coins given these rules:

- with each grab, exactly $1 is retrieved
- the same denomination of coin is always retrieved for a given "run"
- the time to complete the task is only related to the number of grabs, not the number of coins obtained

Regardless of the denomination of the coins grabbed, I need to grab 100 times. I could grab 4 quarters, or 10 dimes or 20 nickels or 100 pennies and each grab "performs" the same.
