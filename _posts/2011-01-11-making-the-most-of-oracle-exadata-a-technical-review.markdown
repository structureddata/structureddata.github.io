---
author: Greg Rahn
comments: true
date: 2011-01-11T19:00:11.000Z
layout: post
slug: making-the-most-of-oracle-exadata-a-technical-review
title: Making the Most of Oracle Exadata – A Technical Review
wp_id: 1271
wp_categories:
  - Exadata
  - Oracle
wp_tags:
  - EHCC
  - Exadata
  - Smart Flash Cache
  - Smart Scan
  - Storage Indexes
---

Over the past few weeks several people have asked me about an Exadata article entitled "[Making the Most of Oracle Exadata](http://www.nocoug.org/Journal/NoCOUG_Journal_201008.pdf#page=8)" by Marc Fielding of Pythian.  Overall it's an informative article and touches on many of the key points of Exadata, however,  even though I read (skimmed is a much better word) and [briefly commented](http://www.pythian.com/news/15425/making-the-most-of-exadata/) on the article back in August, after further review I found some technical inaccuracies with this article so I wanted to take the time to clarify this information for the Exadata community.

### Exadata Smart Scans

Marc writes:

> Smart scans: Smart scans are Exadata's headline feature. They provide three main benefits: reduced data transfer volumes from storage servers to databases, CPU savings on database servers as workload is transferred to storage servers, and improved buffer cache efficiency thanks to column projection. Smart scans use helper processes that function much like parallel query processes but run directly on the storage servers. Operations off-loadable through smart scans include the following:
>
>   * _Predicate filtering_ - processing WHERE clause comparisons to literals, including logical operators and most SQL functions.
>   * _Column projection_ - by looking at a query's SELECT clause, storage servers return only the columns requested, which is a big win for wide tables.
>   * _Joins_ - storage servers can improve join performance by using Bloom filters to recognize rows matching join criteria during the table scan phase, avoiding most of the I/O and temporary space overhead involved in the join processing.
>   * _Data mining model scoring_ - for users of Oracle Data Mining, scoring functions like PREDICT() can be evaluated on storage servers.

I personally would not choose a specific number of benefits from Exadata Smart Scan, simply stated, the design goal behind Smart Scan is to reduce the amount of data that is sent from the storage nodes (or storage arrays) to the database nodes (why move data that is not needed?).  Smart Scan does this in two ways: it applies the appropriate column projection and row restriction rules to the data as it streams off of disk.  However, projection _is not_ limited to just columns in the SELECT clause, as Marc mentions, it also includes columns in the WHERE clause as well.  Obviously JOIN columns need to be projected to perform the JOIN in the database nodes.  The one area that Smart Scan _does not_ help with at all is improved buffer cache efficiency.  The reason for this is quite simple: Smart Scan returns data in blocks that were created on-the-fly just for that given query -- it contains only the needed columns (projections) and has rows filtered out from the predicates (restrictions).  Those blocks could not be reused unless someone ran the exact same query (think of those blocks as custom built just for that query).  The other thing is that Smart Scans use direct path reads (cell smart table scan) and these reads are done into the PGA space, not the shared SGA space (buffer cache).

As most know, Exadata can easily push down simple predicates filters (`WHERE c1 = 'FOO'`) that can be applied as restrictions with Smart Scan.  In addition, Bloom Filters can be applied as restrictions for simple JOINs, like those commonly found in Star Schemas (Dimensional Data Models).  These operations can be observed in the query execution plan by the `JOIN FILTER CREATE` and `JOIN FILTER USE` row sources.   What is very cool is that Bloom Filters can also pass their list of values to Storage Indexes to aid in further I/O reductions if there is natural clustering on those columns or it eliminates significant amounts of data (as in a highly selective set of values).  Even if there isn't significant data elimination via Storage Indexes, a Smart Scan Bloom Filter can be applied post scan to prevent unneeded data being sent to the database servers.

### Exadata Storage Indexes

Marc writes:

> Storage indexes: Storage indexes reduce disk I/O volumes by tracking high and low values in memory for each 1-megabyte storage region. They can be used to give partition pruning benefits without requiring the partition key in the WHERE clause, as long as one of these columns is correlated with the partition key. For example, if a table has order_date and processed_date columns, is partitioned on order_date, and if orders are processed within 5 days of receipt, the storage server can track which processed_date values are included in each order partition, giving partition pruning for queries referring to either order_date or processed_date. Other data sets that are physically ordered on disk, such as incrementing keys, can also benefit.

In Marc's  example he states there is correlation between the two columns PROCESSED_DATE and ORDER_DATE where PROCESSED_DATE = ORDER_DATE + [0..5 days].  That's fine and all, but to claim partition pruning takes place when specifying ORDER_DATE (the partition key column) or PROCESSED_DATE (non partition key column) in the WHERE clause because the Storage Index can be used for PROCESSED_DATE is inaccurate. The reality is, partition pruning can only take place when the partition key, ORDER_DATE, is specified, regardless if a Storage Index is used for PROCESSED_DATE.

Partition Pruning and Storage Indexes are completely independent of each other and Storage Indexes know absolutely nothing about partitions, even if the partition key column and another column have some type of correlation, as in Marc's example.  The Storage Index simply will track which Storage Regions do or do not have rows that match the predicate filters and eliminate reading the unneeded Storage Regions.

### Exadata Hybrid Columnar Compression

Marc writes:

> Columnar compression: Hybrid columnar compression (HCC) introduces a new physical storage concept, the compression unit. By grouping many rows together in a compression unit, and by storing only unique values within each column, HCC provides storage savings in the range of 80 90% based on the compression level selected. Since data from full table scans remains compressed through I/O and buffer cache layers, disk savings translate to reduced I/O and buffer cache work as well. HCC does, however, introduce CPU and data modification overhead that will be discussed in the next section.

The Compression Unit (CU) for Exadata Hybrid Columnar Compression (EHCC) is actually a logical construct, not a physical storage concept.  The compression gains from EHCC come from column-major organization of the rows contained in the CU and the encoding and transformations (compression) that can be done because of that organization (like values are more common within the same column across rows, vs different columns in the same row).   To say EHCC only stores unique values within each column is inaccurate, however, the encoding and transformation algorithms use various techniques that yield very good compression by attempting to represent the column values with as few bytes as possible.

Data from EHCC full table scans only remains fully compressed if the table scan _is not_ a Smart Scan, in which case the compressed CUs are passed directly up to the buffer cache and the decompression will then be done by the database servers.  However, if the EHCC full table scan is a Smart Scan, then only the columns and rows being returned to the database nodes are decompressed by the Exadata servers, however, predicate evaluations can be performed directly on the EHCC compressed data.

Read more: [Exadata Hybrid Columnar Compression Technical White Paper](http://www.oracle.com/technetwork/middleware/bi-foundation/ehcc-twp-131254.pdf)

Marc also writes:

>Use columnar compression judiciously: Hybrid columnar compression (HCC) in Exadata has the dual advantages of reducing storage usage and reducing I/O for large reads by storing data more densely. However, HCC works only when data is inserted using bulk operations. If non-compatible operations like single-row inserts or updates are attempted, Exadata reverts transparently to the less restrictive OLTP compression method, losing the compression benefits of HCC. When performing data modifications such as updates or deletes, the entire compression unit must be uncompressed and written in OLTP-compressed form, involving an additional disk I/O penalty as well.

EHCC does require bulk direct path load operations to work.  This is because the compression algorithms that are used for EHCC need sets of rows as input, not single rows.  What is incorrect with Marc's comments is that when a row in a CU is modified (UPDATE or DELETE), the entire CU _is not_ uncompressed and changed to non-EHCC compression, only the rows that are UPDATED are migrated to non-EHCC compression.  For DELETEs no row migrations take place at all. This is easily demonstrated by tracking ROWIDs as in the example at the bottom of this post.

### Exadata Smart Flash Cache

Marc writes:

> Flash cache: Exadata s flash cache supplements the database servers  buffer caches by providing a large cache of 384 GB per storage server and up to 5 TB in a full Oracle Exadata Database Machine, considerably larger than the capacity of memory caches. Unlike generic caches in traditional SAN storage, the flash cache understands database-level operations, preventing large non-repeated operations such as backups and large table scans from polluting the cache. Since flash storage is nonvolatile, it can cache synchronous writes, providing performance benefits to commit-intensive applications.

While flash (SSD) storage is indeed non-volatile, the Exadata Smart Flash Cache _is_ volatile - it loses all of its contents if the Exadata server is power cycled.  Also, since the Exadata Smart Flash is currently a write-through cache, it offers no _direct_ performance advantages to commit-intensive applications, however, it does offer _indirect_ performance advantages by servicing read requests that would otherwise be serviced by the HDDs, thus allowing the HDDs to service more write operations.

Read more: [Exadata Smart Flash Cache Technical White Paper](http://www.oracle.com/technetwork/middleware/bi-foundation/exadata-smart-flash-cache-twp-v5-1-128560.pdf)

### EHCC UPDATE and DELETE Experiment

```
--
-- EHCC UPDATE example - only modified rows migrate
--

SQL> create table order_items1
  2  compress for query high
  3  as
  4  select rownum as rnum, x.*
  5  from order_items x
  6  where rownum <= 10000;

Table created.

SQL> create table order_items2
  2  as
  3  select rowid as rid, x.*
  4  from order_items1 x;

Table created.

SQL> update order_items1
  2  set quantity=10000
  3  where rnum in (1,100,1000,10000);

4 rows updated.

SQL> commit;

Commit complete.

SQL> select b.rnum, b.rid before_rowid, a.rowid after_rowid
  2  from order_items1 a, order_items2 b
  3  where a.rnum(+) = b.rnum
  4  and (a.rowid != b.rid
  5    or a.rowid is null)
  6  order by b.rnum
  7  ;

           RNUM BEFORE_ROWID       AFTER_ROWID
--------------- ------------------ ------------------
              1 AAAWSGAAAAAO1aTAAA AAAWSGAAAAAO1aeAAA
            100 AAAWSGAAAAAO1aTABj AAAWSGAAAAAO1aeAAB
           1000 AAAWSGAAAAAO1aTAPn AAAWSGAAAAAO1aeAAC
          10000 AAAWSGAAAAAO1aXBEv AAAWSGAAAAAO1aeAAD

--
-- EHCC DELETE example - no rows migrate
--

SQL> create table order_items1
  2  compress for query high
  3  as
  4  select rownum as rnum, x.*
  5  from order_items x
  6  where rownum <= 10000;

Table created.

SQL> create table order_items2
  2  as
  3  select rowid as rid, x.*
  4  from order_items1 x;

Table created.

SQL> delete from order_items1
  2  where rnum in (1,100,1000,10000);

4 rows deleted.

SQL> commit;

Commit complete.

SQL> select b.rnum, b.rid before_rowid, a.rowid after_rowid
  2  from order_items1 a, order_items2 b
  3  where a.rnum(+) = b.rnum
  4  and (a.rowid != b.rid
  5    or a.rowid is null)
  6  order by b.rnum
  7  ;

           RNUM BEFORE_ROWID       AFTER_ROWID
--------------- ------------------ ------------------
              1 AAAWSIAAAAAO1aTAAA
            100 AAAWSIAAAAAO1aTABj
           1000 AAAWSIAAAAAO1aTAPn
          10000 AAAWSIAAAAAO1aXBEv
```