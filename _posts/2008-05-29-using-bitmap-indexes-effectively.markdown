---
author: Greg Rahn
comments: true
date: 2008-05-29T08:00:20.000Z
layout: post
slug: using-bitmap-indexes-effectively
title: Using Bitmap Indexes Effectively
wp_id: 65
wp_categories:
  - 10gR2
  - 11gR1
  - Data Warehousing
  - Execution Plans
  - Optimizer
  - Performance
  - SQL Tuning
  - Statistics
  - Troubleshooting
  - VLDB
wp_tags:
  - bitmap index
  - cardinality
  - execution plan
  - i/o throughput
  - selectivity
---

Recently I was reading this thread, "[Trying to make use of bitmap indexes](http://forums.oracle.com/forums/thread.jspa?threadID=660323&start=0&tstart=0)" on the [Oracle Forum](http://forums.oracle.com/).   Before I had finished a working example, [Jonathan Lewis](http://jonathanlewis.wordpress.com/) had posted [his response](http://forums.oracle.com/forums/message.jspa?messageID=2545758#2545758) which was on par with my thoughts.  Since this is a topic I see frequently, I thought I would finish my experiment and publish it here.

### What We Are Given

The author of the original post had stated that the table in question contains about 16 million rows and states: 
> The table contains three IDEAL columns for bitmap indexes the first of which may have only two, the second three and the third four distinct values.  I was planning to change the index type on these columns to BITMAP [from B-tree].
To keep the focus of this post narrow, I'm only going to discuss whether or not one should consider bitmap indexes for queries, and not discuss potential update related issues.

### The Data

For this experiment, I'm going to create a table that has three columns with the given NDV from above and add in a few extra filler columns to pad it out a bit.  Since I do not know the exact table structure, I'll just go with a simple example.  In reality, the posters table may be wider, but for this example, it is what it is.

```
create table bm_test
nologging compress
as
select
  round(dbms_random.value(1, 2)) a  -- NDV 2
, round(dbms_random.value(1, 3)) b  -- NDV 3
, round(dbms_random.value(1, 4)) c  -- NDV 4
, to_char(800000+100000*dbms_random.normal,'fm000000000000') c3
, to_char(800000+100000*dbms_random.normal,'fm000000000000') c4
, to_char(15000+2000*dbms_random.normal,'fm000000') c5
, to_char(80000+10000*dbms_random.normal,'fm000000000000') c6
from dual
connect by level &lt;= 16000000
/

desc bm_test
 Name		   Null?    Type
 ----------------- -------- ------------
 A			    NUMBER
 B			    NUMBER
 C			    NUMBER
 C3			    VARCHAR2(13)
 C4			    VARCHAR2(13)
 C5			    VARCHAR2(7)
 C6			    VARCHAR2(13)

exec dbms_stats.gather_table_stats(user,'BM_TEST');

create bitmap index bm1 on bm_test(a);
create bitmap index bm2 on bm_test(b);
create bitmap index bm3 on bm_test(c);

select a, b, c, count(*)
from bm_test
group by a,b,c
order by a,b,c;

         A          B          C   COUNT(*)
---------- ---------- ---------- ----------
         1          1          1     333292
         1          1          2     666130
         1          1          3     666092
         1          1          4     333585
         1          2          1     668594
         1          2          2    1332121
         1          2          3    1332610
         1          2          4     668608
         1          3          1     333935
         1          3          2     666055
         1          3          3     666619
         1          3          4     333106
         2          1          1     333352
         2          1          2     665038
         2          1          3     665000
         2          1          4     333995
         2          2          1     669120
         2          2          2    1332744
         2          2          3    1332766
         2          2          4     668411
         2          3          1     333891
         2          3          2     665924
         2          3          3     664799
         2          3          4     334213

24 rows selected.

select segment_name,
       segment_type,
       sum(blocks) blocks,
       sum(bytes)/1024/1024 mb
from user_segments
where segment_name like 'BM%'
group by segment_name, segment_type;

SEGMENT_NAME SEGMENT_TYPE     BLOCKS         MB
------------ ------------ ---------- ----------
BM_TEST      TABLE            102592      801.5
BM1          INDEX               768          6
BM2          INDEX              1152          9
BM3          INDEX              1408         11

select object_name, object_id
from user_objects
where object_name like 'BM%';

OBJECT_NAME   OBJECT_ID
------------ ----------
BM_TEST           54744
BM1               54745
BM2               54746
BM3               54747

```

### The Queries And Execution Plans

The original post did not contain any queries or predicates, so for the purpose of this example I'm going to assume that there are exactly three predicates, one on each of column A, B and C, and that each predicate is a single equality (e.g. A=1 and B=1 and C=1).  Looking at the data distribution from the query above, we observe there are approximately three different grouping counts: the lower around 333,000 the middle around 666,000 and the upper around 1,300,000.  I will choose tuples from each of these groupings for the three test cases.

#### Query A

```
select *
from bm_test
where a=1 and b=1 and c=1;

333292 rows selected.

Plan hash value: 3643416817

----------------------------------------------------------------------------------------
| Id  | Operation                    | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |         |       |       | 23314 (100)|          |
|   1 |  TABLE ACCESS BY INDEX ROWID | BM_TEST |   326K|    17M| 23314   (1)| 00:04:40 |
|   2 |   BITMAP CONVERSION TO ROWIDS|         |       |       |            |          |
|   3 |    BITMAP AND                |         |       |       |            |          |
|*  4 |     BITMAP INDEX SINGLE VALUE| BM3     |       |       |            |          |
|*  5 |     BITMAP INDEX SINGLE VALUE| BM2     |       |       |            |          |
|*  6 |     BITMAP INDEX SINGLE VALUE| BM1     |       |       |            |          |
----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - access("C"=1)
   5 - access("B"=1)
   6 - access("A"=1)
```

#### Query B

```
select *
from bm_test
where a=1 and b=1 and c=2;

666130 rows selected.

Plan hash value: 3202922749

----------------------------------------------------------------------------------------
| Id  | Operation                    | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |         |       |       | 27105 (100)|          |
|   1 |  TABLE ACCESS BY INDEX ROWID | BM_TEST |   653K|    34M| 27105   (1)| 00:05:26 |
|   2 |   BITMAP CONVERSION TO ROWIDS|         |       |       |            |          |
|   3 |    BITMAP AND                |         |       |       |            |          |
|*  4 |     BITMAP INDEX SINGLE VALUE| BM2     |       |       |            |          |
|*  5 |     BITMAP INDEX SINGLE VALUE| BM1     |       |       |            |          |
|*  6 |     BITMAP INDEX SINGLE VALUE| BM3     |       |       |            |          |
----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - access("B"=1)
   5 - access("A"=1)
   6 - access("C"=2)
```

#### Query C

```
sql']select *
from bm_test
where a=1 and b=2 and c=2;

1332121 rows selected.

Plan hash value: 1873942893

-----------------------------------------------------------------------------
| Id  | Operation         | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |         |       |       | 28243 (100)|          |
|*  1 |  TABLE ACCESS FULL| BM_TEST |  1377K|    72M| 28243   (2)| 00:05:39 |
-----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter(("C"=2 AND "B"=2 AND "A"=1))
```

As you can see from the execution plans, Query A and B use the bitmap indexes and Query C uses a Full Table Scan.  Of the 16,000,000 rows, Query A returns 333,292 (2.08%), Query B returns 666,130 (4.16%) and Query C returns 1,332,121 rows (8.33%).  I think it is important to note that the change in the execution plan from index access to table scan is due to the costing, not directly due to the percentage of data returned.

#### Execution Times

I'm going to gather two sets of execution times.  The first will be with a cold buffer cache, and the second with a warm buffer cache.  All elapsed times are in seconds.

Query | Execution Plan | Cold Cache (seconds) | Warm Cache (seconds)
--- | --- | --- | ---
A | Bitmap Index | 38 | 3
B | Bitmap Index | 40 | 4
C | FTS	         | 16 | 16

As you can see from the execution times, there is a significant difference (approx. 11x) between the cold and warm cache executions of each Query A and Query B.  The other observation is that Query C (FTS) is faster than Query A (Index Access) on a cold cache. We surely need to account for this.  One observation I made (from iostat) is that the I/O throughput rate for Query A and Query B was around 23MB/s while the I/O rate for Query C was around the 55MB/s range during the cold cache execution.  None of the queries used the Parallel Query Option.

Lets take a look at the tkprof output from both the cold and warm cache executions of Query A and see if we can find where the time is being spent.  The traces were collected using event 10046, level 8.

#### Query A TKPROF - Warm Cache

```
select /* warm cache */ *
from bm_test
where a=1 and b=1 and c=1


call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch     3334      2.20       2.17          0     102184          0      333292
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total     3336      2.20       2.18          0     102184          0      333292

Misses in library cache during parse: 0
Optimizer mode: ALL_ROWS
Parsing user id: 31

Rows     Row Source Operation
-------  ---------------------------------------------------
 333292  TABLE ACCESS BY INDEX ROWID BM_TEST (cr=102184 pr=0 pw=0 time=19332 us cost=23314 size=17945290 card=326278)
 333292   BITMAP CONVERSION TO ROWIDS (cr=1162 pr=0 pw=0 time=2329 us)
     92    BITMAP AND  (cr=1162 pr=0 pw=0 time=1691 us)
    642     BITMAP INDEX SINGLE VALUE BM3 (cr=367 pr=0 pw=0 time=104 us)(object id 54747)
    697     BITMAP INDEX SINGLE VALUE BM2 (cr=396 pr=0 pw=0 time=92 us)(object id 54746)
    727     BITMAP INDEX SINGLE VALUE BM1 (cr=399 pr=0 pw=0 time=117 us)(object id 54745)


Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                    3337        0.00          0.00
  SQL*Net message from client                  3337        0.00          1.04
```

When the cache is warm, there are no physical reads that take place.  This would explain the fast execution of the query.

**Note:** For Bitmap execution plans, the number that appears in the rows column is actually bitmap fragments (compressed rowids), not actual rows.  This is why the number looks suspiciously small.

#### Query A TKPROF - Cold Cache

```
select /* cold cache */ *
from bm_test
where a=1 and b=1 and c=1

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch     3334     11.44      36.22      99722     102184          0      333292
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total     3336     11.45      36.22      99722     102184          0      333292

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 31

Rows     Row Source Operation
-------  ---------------------------------------------------
 333292  TABLE ACCESS BY INDEX ROWID BM_TEST (cr=102184 pr=99722 pw=99722 time=294694 us cost=23314 size=17945290 card=326278)
 333292   BITMAP CONVERSION TO ROWIDS (cr=1162 pr=1041 pw=1041 time=2490 us)
     92    BITMAP AND  (cr=1162 pr=1041 pw=1041 time=5104 us)
    642     BITMAP INDEX SINGLE VALUE BM3 (cr=367 pr=324 pw=324 time=1840 us)(object id 54747)
    697     BITMAP INDEX SINGLE VALUE BM2 (cr=396 pr=351 pw=351 time=1817 us)(object id 54746)
    727     BITMAP INDEX SINGLE VALUE BM1 (cr=399 pr=366 pw=366 time=1534 us)(object id 54745)

Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                    3336        0.00          0.00
  SQL*Net message from client                  3336        0.00          1.12
  db file sequential read                     99722        0.04         30.60
```

As you can see the majority of the time was spent on `db file sequential read` doing the 99,722 physical reads.  This explains the difference in elapsed time between the cold and warm cache executions of Query A: it comes down to physical I/O.  But why does Query C run in half the time that Query A runs in when the cache is cold, given that Query C is doing a FTS and Query A is not?  Shouldn't the FTS plan be slower than the index plan?

Looking at the raw trace file for Query A, we observe the following:

```
WAIT #2: nam='db file sequential read' ela= 241 file#=1 block#=1770152 blocks=1 obj#=54744 tim=1212013191665924
WAIT #2: nam='db file sequential read' ela= 232 file#=1 block#=1770153 blocks=1 obj#=54744 tim=1212013191666240
WAIT #2: nam='db file sequential read' ela= 351 file#=1 block#=1770156 blocks=1 obj#=54744 tim=1212013191666650
WAIT #2: nam='db file sequential read' ela= 240 file#=1 block#=1770157 blocks=1 obj#=54744 tim=1212013191666948
WAIT #2: nam='db file sequential read' ela= 298 file#=1 block#=1770158 blocks=1 obj#=54744 tim=1212013191667306
```

As you can see, the table is being read sequentially 1 block at a time.  Let's examine the TKPROF from Query C.

#### Query C TKPROF

```
select *
from bm_test
where a=1 and b=2 and c=2

call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch    13323      5.99      11.17     102592     115831          0     1332121
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total    13325      5.99      11.17     102592     115831          0     1332121

Misses in library cache during parse: 1
Optimizer mode: ALL_ROWS
Parsing user id: 31

Rows     Row Source Operation
-------  ---------------------------------------------------
1332121  TABLE ACCESS FULL BM_TEST
(cr=115831 pr=102592 pw=102592 time=102744 us cost=28243 size=75768825 card=1377615)

Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  SQL*Net message to client                   13325        0.00          0.01
  SQL*Net message from client                 13325        0.00          4.23
  db file sequential read                         2        0.02          0.03
  direct path read                              952        0.08          5.20
```

The majority of the time is spent on `direct path read`.

Let's dig deeper and look at the raw trace file from Query C.

```
WAIT #2: nam='direct path read' ela= 6029 file number=1 first dba=1785609 block cnt=128 obj#=54744 tim=1212013229612857
WAIT #2: nam='direct path read' ela= 8638 file number=1 first dba=1787017 block cnt=128 obj#=54744 tim=1212013229628256
WAIT #2: nam='direct path read' ela= 7019 file number=1 first dba=1789193 block cnt=128 obj#=54744 tim=1212013229642410
WAIT #2: nam='direct path read' ela= 9276 file number=1 first dba=1791497 block cnt=128 obj#=54744 tim=1212013229658400
WAIT #2: nam='direct path read' ela= 6173 file number=1 first dba=1792777 block cnt=128 obj#=54744 tim=1212013229671314
```

As you can see with Query C, the read size is 128 blocks or 1MB (128 blocks * 8k block), the largest I/O that Oracle will issue.  This explains the difference in the observed I/O throughput (23MB/s vs. 55MB/s): the bitmap index plan reads the table 1 block at a time, and the FTS reads (most of) it 128 blocks at a time.  It makes good sense that if the read throughput rate is ~2x (23MB/s vs. 55MB/s) then the execution time would be ~0.5 as long (38 seconds vs. 16 seconds).  The larger I/O size will have a higher throughput rate compared to a smaller I/O size.  The exact breakdown of the multi-block reads are:

```
BLOCK_COUNT      COUNT TOTAL_BLOCKS
----------- ---------- ------------
          7          2           14
          8        106          848
          9         34          306
         16         10          160
         33          8          264
        119         42         4998
        128        750        96000
            ---------- ------------
sum                952       102590
```

### Making Sense Of All The Observations

If we look at the tkprof output again from Query A, we see there are 99,722 waits on `db file sequential read`.  Of those 99,722 waits, 98,681 are on the table (`grep` is our friend here using the raw trace file and the event and object number), the remaining are for the indexes.  This tells us that 98,681 out of 102,592 total blocks of the table were retrieved, just 1 block at a time.  Basically we have done a very inefficient full table scan.  This explains our two observations: 1) why the FTS is faster than the index access plan with a cold cache and 2) why the FTS has a higher read throughput than the index access plan.  It all comes down to efficient physical I/O.

### The Big Picture

Just because a column has a low NDV does not necessarily mean it is an ideal candidate for a bitmap index.  Just like B-tree indexes, bitmap indexes are best leveraged when the combination of them makes it very selective (returns only a small number of rows).  The classic example of using a bitmap index on a gender column (male/female) is a horrible one in my opinion.  If there are only two values, and there is an even distribution of data, 50% selectivity is too large and thus not a good candidate for a bitmap index.  Would you use any index to access 50% of a table?

Bitmap indexes can be very useful in making queries run fast, but if the `BITMAP CONVERSION TO ROWIDS` returns a large list of rowids, you may find that a FTS (or partition scan) may yield better performance, but may use more I/O resources.  It comes down to a trade off: If there is a high buffer cache hit rate for the objects in the bitmap plans, it will run reasonably fast and requite less physical I/O.  If the objects are unlikely to be in the buffer cache, a FTS will yield better performance as long as it is not bottlenecked on I/O bandwidth.
