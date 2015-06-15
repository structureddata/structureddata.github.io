---
author: Greg Rahn
comments: true
date: 2010-08-10
layout: post
slug: oracle-exadata-and-netezza-twinfin-compared-an-engineers-analysis
title: Oracle Exadata and Netezza TwinFin Compared – An Engineer’s Analysis
wp_id: 1053
wp_categories:
  - Data Warehousing
  - Exadata
  - Oracle
wp_tags:
  - Exadata
  - Netezza
  - Oracle
  - Teradata
  - TwinFin
---

There seems to be little debate that Oracle's launch of the [Oracle Exadata Storage Server](http://www.oracle.com/us/products/database/exadata/index.htm) and the [Sun Oracle Database Machine](http://www.oracle.com/us/products/database/database-machine/index.html) has created buzz in the database marketplace.  Apparently there is so much buzz and excitement around these products that two competing vendors, Teradata and Netezza, have both authored publications that contain a significant amount of discussion about the Oracle Database with Real Application Clusters (RAC) and Oracle Exadata.  Both of these vendor papers are well structured but make no mistake, these are marketing publications written with the intent to be critical of Exadata and discuss how their product is potentially better.  Hence, both of these papers are obviously biased to support their purpose.

My intent with this blog post is simply to discuss some of the claims, analyze them for factual accuracy, and briefly comment on them.  After all, Netezza clearly states in their publication:
<blockquote>The information shared in this paper is made available in the spirit of openness. Any inaccuracies result from our mistakes, not an intent to mislead.</blockquote>

In the interest of full disclosure, my employer is [Oracle Corporation](http://oracle.com/), however, this is a personal blog and what I write here are my own ideas and words (see disclaimer on the right column).  For those of you who don't know, I'm a database performance engineer with the Real-World Performance Group which is part of Server Technologies.  I've been working with Exadata since before it was launched publicly and have worked on dozens of data warehouse proofs-of-concept (PoCs) running on the Exadata powered Sun Oracle Database Machine.  My thoughts and comments are presented purely from an engineer's standpoint.

The following writings are the basis of my discussion:

1. Teradata: [Exadata - the Sequel: Exadata V2 is Still Oracle](http://www.teradata.com/t/white-papers/Exadata-the-Sequel-Exadata-V2-is-Still-Oracle/)
2. Daniel Abadi: [Defending Oracle Exadata](http://dbmsmusings.blogspot.com/2010/08/defending-oracle-exadata.html)
3. Netezza: [Oracle Exadata and Netezza TwinFin™ Compared](http://www.netezza.com/exadata-twinfin-compared/)

If you have not read Daniel Abadi's blog post I strongly suggest you do before proceeding further.  I think it is very well written and is presented from a vendor neutral point of view so there is no marketing gobbledygook to sort through.  Several of the points in the Teradata writing which he discusses are also presented (or similarly presented) in the Netezza eBook, so you can relate his responses to those arguments as well.  Since I feel Daniel Abadi did an excellent job pointing out the major flaws with the Teradata paper, I'm going to limit my discuss to the Netezza eBook.

### Understanding Exadata Smart Scan

As a prerequisite for the discussion of the Netezza and Teradata papers, it's imperative that we take a minute to understand the basics of Exadata Smart Scan.  The Smart Scan optimizations include the following:

- Data Elimination via Storage Indexes
- Restriction/Row Filtering/Predicate Filtering
- Projection/Column Filtering
- Join Processing/Filtering via Bloom Filters and Bloom Pruning

The premise of these optimizations is reduce query processing times in the following ways:

- **I/O Elimination** - don't read data off storage that is not needed
- **Payload Reduction** - don't send data to the Oracle Database Servers that is not needed

OK.  Now that you have a basic understanding, let's dive into the claims...

### Netezza's Claims

Let's discuss a few of Netezza claims against Exadata:

#### Claim: Exadata Smart Scan does not work with index-organized tables or clustered tables.

While this is a true statement, its intent is clearly to mislead you.  Both of these structures are designed for OLTP workloads, not data warehousing. In fact, if one were to actually read the [Oracle Database 11.2 documentation](http://www.oracle.com/pls/db112/homepage) for index-organized tables you would find the following ([source](http://download.oracle.com/docs/cd/E14072_01/server.112/e10595/tables012.htm#i1007016)):

> Index-organized tables are **ideal for OLTP applications**, which require fast primary key access

If one were to research table clusters you would find the Oracle Database 11.2 documentation offers the following guidelines ([source](http://download.oracle.com/docs/cd/E11882_01/server.112/e10713/tablecls.htm#CNCPT608)):

> Typically, clustering tables **is not appropriate** in the following situations:
>
>   - The tables are frequently updated.
>   - The tables frequently require a full table scan.
>   - The tables require truncating.

As anyone can see from the Oracle Database 11.2 Documentation, neither of these structures are appropriate for data warehousing.

Apparently this was not what Netezza really wanted you to know so they uncovered a [note on IOTs](http://www.oracle.com/technology/products/oracle9i/datasheets/iots/iot_ds.html) from almost a decade ago, dating back to 2001 - Oracle 9i time frame, that while it clearly states:

> [an IOT] enables extremely fast access to table data for primary key based [OLTP] queries

it also suggests that an IOT may be used as a fact table.  Clearly this information is quite old and outdated and should probably be removed.  What was a recommendation for Oracle Database 9i Release 1 in 2001 is not necessarily a recommendation for Oracle Database 11g Release 2 in 2010.  Technology changes so using the most recent recommendations as a basis for discussion is appropriate, not some old, outdated stuff from nearly 10 years ago.  Besides, the Oracle Database Machine runs version 11g Release 2, not 9i Release 1.

**Bottom line:** I'd say this "limitation" has an impact on a nice round number of Exadata data warehouse customers - exactly zero (zero literally being a round number).  IOTs and clustered tables are both structures optimized for fast primary key access, like the type of access in OLTP workloads, not data warehousing.  The argument that Smart Scan does not work for these structures is really no argument at all.

#### Claim: Exadata Smart Scan does not work with the TIMESTAMP datatype.

Phil Francisco seems to have left out some very important context in making this accusation, because this is not at all what the [cited blog post by Christian Antognini](http://antognini.ch/2010/05/exadata-storage-server-and-the-query-optimizer-%E2%80%93-part-2/) discusses.  This post clearly states the discussion is about:

> What happens [with Smart Scan] when predicates contain functions or expressions?

Nowhere at all does that post make an isolated reference that Smart Scan does not work with the TIMESTAMP datatype.  What this blog post does state is this:

> when a TIMESTAMP datatype is involved **[with datetime functions]**, offloading almost never happens

While the Netezza paper references what the blog post author has written, some very important context has been omitted.  In doing so, Netezza has taken a specific reference and turned it into a misleading generalization.

The reality is that **Smart Scan does indeed work for the TIMESTAMP datatype** and here is a basic example to demonstrate such:

```
SQL> describe t
 Name           Null?    Type
 -------------- -------- ------------------
 ID             NOT NULL NUMBER
 N                       NUMBER
 BF                      BINARY_FLOAT
 BD                      BINARY_DOUBLE
 D                       DATE
 T                       TIMESTAMP(6)
 S                       VARCHAR2(4000)

SQL> SELECT * FROM t WHERE t = to_timestamp('01-01-2010','DD-MM-YYYY');

Execution Plan
----------------------------------------------------------
Plan hash value: 1601196873

----------------------------------------------------------------------------------
| Id  | Operation                 | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------
|   0 | SELECT STATEMENT          |      |     1 |    52 |     4   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS STORAGE FULL| T    |     1 |    52 |     4   (0)| 00:00:01 |
----------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - <span style="background-color:yellow;">storage("T"=TIMESTAMP' 2010-01-01 00:00:00.000000000')</span>
       filter("T"=TIMESTAMP' 2010-01-01 00:00:00.000000000')
```

You can see that the Smart Scan offload is taking place by the presence of the storage clause (highlighted) in the Predicate Information section above.  What Christian Antognini did observe is bug 9682721 and the bugfix resolves the datetime function offload issues for all but a couple scenarios (which he blogs about [here](http://antognini.ch/2010/08/exadata-storage-server-and-the-query-optimizer-%E2%80%93-part-4)) and those operations can (and usually are) expressed differently. For example, an expression using [ADD_MONTHS()](http://download.oracle.com/docs/cd/E11882_01/server.112/e10592/functions009.htm#SQLRF00603) can easily be expressed using [BETWEEN](http://download.oracle.com/docs/cd/E11882_01/server.112/e10592/conditions011.htm#SQLRF52164).

**Bottom line:** Exadata Smart Scan does work with the TIMESTAMP datatype.

#### Claim: When transactions (insert, update, delete) are operating against the data warehouse concurrent with query activity, smart scans are disabled. Dirty buffers turn off smart scan.
Yet again, Netezza presents only a half-truth.  While it is true that an active transaction disables Smart Scan, they fail to further clarify that **Smart Scan is only disabled for those blocks that contain an active transaction - the rest of the blocks are able to be Smart Scanned**.  The amount of data that is impacted by insert, update, delete will generally be a very small fraction of the total data in a data warehouse.  Also, data that is inserted via direct path operations is not subject to [MVCC](http://en.wikipedia.org/wiki/Multiversion_concurrency_control) (the method Oracle uses for read consistency) as the blocks that are used are new blocks so no read consistent view is needed.

**Bottom line:** While this claim is partially true, it clearly attempts to overstate the impact of this scenario in a very negative way.  Not having Smart Scan for small number of blocks will have a negligible impact on performance.

Also see [Daniel Abadi](http://dbmsmusings.blogspot.com/2010/08/defending-oracle-exadata.html): Exadata does NOT Support Active Data Warehousing

#### Claim: Using [a shared-disk] architecture for a data warehouse platform raises concern that contention for the shared resource imposes limits on the amount of data the database can process and the number of queries it can run concurrently.
It is unclear what resource Netezza is referring to here, it simply states "the shared resource".  You know _the_ one?  Yes, _that_ one... Perhaps they mean the disks themselves, but that is completely unknown.  Anyway...

Exadata uses at least a 4 MB Automatic Storage Management (ASM) allocation unit (AU) [[more on ASM basics](http://download.oracle.com/docs/cd/E11882_01/server.112/e10500/asmcon.htm)].  This means that there is at least 4 MB of contiguous physical data laid out on the HDD which translates into 4 MB of contiguous data streamed off of disk for full table scans before the head needs to perform a seek.  With such large I/O requests the HDDs are able to spend nearly all the time transferring data, and very little time finding it and that is what matters most.  Clearly if Exadata is able to stream data off of disk at 125 MB/s per disk (near physics speed for this type of workload) then any alleged "contention" is really not an issue.  In many multi-user data warehouse workloads for PoCs, I've observed that each Exadata Storage Server is able to perform very close or at the data sheet physical HDD I/O rate of 1500 MB/s per server.

**Bottom line:** The scalability differences between shared-nothing and shared-disk are very much exaggerated. By doing large sequential I/Os the disk spends its time returning data, not finding it.  Simply put - there really is no "contention".

Also see [Daniel Abadi](http://dbmsmusings.blogspot.com/2010/08/defending-oracle-exadata.html): 1) Exadata does NOT Enable High Concurrency & 2) Exadata is NOT Intelligent Storage; Exadata is NOT Shared-Nothing

#### Claim: Analytical queries, such as "find all shopping baskets sold last month in Washington State, Oregon and California containing product X with product Y and with a total value more than $35" must retrieve much larger data sets, all of which must be moved from storage to database.
I find it so ironic that Netezza mentions this type of query as nearly an identical (but more complex) one was used by my group at Oracle OpenWorld 2009 in our [The Terabyte Hour with the Real-World Performance Group](/2009/07/20/oracle-openworld-2009-the-real-world-performance-group/) session.  The exact analytical query we ran live for the audience to demonstrate the features of Oracle Exadata and the Oracle Database Machine was, "What were the most popular items in the baskets of shoppers who visited stores in California in the first week of May and did not buy bananas?"

Let's translate the Netezza analytical question into some tables and SQL to see what the general shape of this query may look like:

```
select
   count(*)  -- using count(*) for simplicity of the example
from (
   select
      td.transaction_id,
      sum(td.sales_dollar_amt) total_sales_amt,
      sum(case when p.product_description in ('Brand #42 beer') then 1 else 0 end) count_productX,
      sum(case when p.product_description in ('Brand #42 frozen pizza') then 1 else 0 end) count_productY
   from transaction_detail td
      join d_store s   on (td.store_key = s.store_key)
      join d_product p on (td.product_key = p.product_key)
   where
      s.store_state in ('CA','OR','WA') and
      td.transaction_time >= timestamp '2010-07-01 00:00:00' and
      td.transaction_time <  timestamp '2010-08-01 00:00:00'
   group by td.transaction_id
) x
where
   total_sales_amt > 35 and
   count_productX > 0 and
   count_productY > 0
```

To me, this isn't a particularly complex analytical question/query.  As written, it's just a 3 table join (could be 4 if I added a D_DATE I suppose), but it doesn't require anything fancy - just a simple GROUP BY with a CASE in the SELECT to count how many times Product X and Product Y appear in a given basket.

Netezza claims that analytical queries like this one must move all the data from storage to the database, but that simply is not true.  Here is why:

1. Simple range partitioning on the event timestamp (a very common data warehousing practice for those databases that support partitioning), or even Exadata Storage Indexes, will eliminate any I/O for data other than the one month window that is required for this query.
2. A bloom filter can be created and pushed into Exadata to be used as a storage filter for the list of STORE_KEY values that represent the three state store restriction.

Applying both of #1 and #2, the only data that is returned to the database for the fact table are rows for stores in Washington State, Oregon and California for last month.  Clearly this is only a subset of the data for the entire fact table.

This is just one example, but there are obviously different representations of the same data and query that could be used.  I chose what I thought was the most raw, unprocessed, uncooked form simply because Netezza seems to boast about brute force type of operations.  Even then, considering a worst case scenario, Exadata does not have to move all the data back to the database. Other data/table designs that I've seen from customers in the retail business would allow even less data to be returned.

**Bottom line:** There are numerous ways that Exadata can restrict the data that is set to the database servers and it's likely that any query with any predicate restrictions can do so. Certainly it is possible even with the analytic question that Netezza mentions.

#### Claim: To evenly distribute data across Exadata's grid of storage servers requires administrators trained and experienced in designing, managing and maintaining complex partitions, files, tablespaces, indices, tables and block/extent sizes.
Interestingly enough, the author of the Teradata paper seems to have a better grasp than Netezza on how data distribution and ASM work describing it on page 9:

> Distribution of data on Exadata storage is managed by Oracle's Automatic Storage Manager (ASM). By default, ASM stripes each Oracle data partition across all available disks on every Exadata cell.

So if by default ASM evenly stripes data across all available disks on Exadata Storage Server (and it does, in a round robin manner) what exactly is so difficult here?  What training and experience is really required for something that does data distribution automatically? I can only assert that Phil Francisco has not even read the Teradata paper (but it would seem he has since he even mentions it on [his blog](http://www.enzeecommunity.com/blogs/nzblog/2010/08/04/four-fundamental-differences-between-twinfin-and-exadata)), let alone [Introduction to Oracle Automatic Storage Management](http://download.oracle.com/docs/cd/E11882_01/server.112/e10500/asmcon.htm).  It's claims like this that really make me question how genuine his "no intent to mislead" statement really is.

**Bottom line:** Administrators need not worry about data distribution with Exadata and ASM - it is done automatically and evenly for you.

### Conclusion

I'm always extremely reluctant to believe much of what vendors say about other vendors, especially when they preface their publication with something like: "One caveat: Netezza has no direct access to an Exadata machine", and "Any inaccuracies result from our mistakes, not an intent to mislead" yet they still feel qualified enough to write about said technology and claim it as fact. I also find it interesting that both Teradata and Netezza have published anti-Exadata papers, but neither Netezza nor Teradata have published anti-vendor papers about each other (that I know of). Perhaps Exadata is much more of a competitor than either of them let on. They do protest too much, methinks.

The list of claims I've discussed certainly is not an exhaustive list by any means but I think it is fairly representative of the quality found in Netezza's paper. While sometimes the facts are correct, the arguments are overstated and misleading.  Other times, the facts are simply wrong.  Netezza clearly attempts to create the illusion of problems simply where they do not exist.

Hopefully this blog post has left you a more knowledgeable person when it comes to Oracle and Exadata.  I've provided fact and example wherever possible and kept assertions to a minimum.

I'd like to end with a quote from Daniel Abadi's response to the Teradata paper which I find more than applicable to the Netezza paper as well:

> Many of the claims and inferences made in the paper about Exadata are overstated, and the reader needs to be careful not to be mislead into believing in the existence problems that don't actually present themselves on realistic data sets and workloads.

Courteous and professional comments are welcome.  Anonymous comments are discouraged.  Snark and flame will end up in the recycle bin.  Comment accordingly.
