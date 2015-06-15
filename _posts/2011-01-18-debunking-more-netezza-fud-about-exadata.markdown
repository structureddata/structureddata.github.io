---
author: Greg Rahn
comments: true
date: 2011-01-18T20:00:20.000Z
layout: post
slug: debunking-more-netezza-fud-about-exadata
title: Debunking More Netezza FUD About Exadata
wp_id: 1304
wp_categories:
  - Exadata
  - Oracle
wp_tags:
  - Bloom Filters
  - Exadata
  - FUD
  - Netezza
---

A reader recently left a comment for which my reply was longer than I'd like to leave for a comment so I'm answering it in detail with this blog post.

Gabramel writes

> Greg,
> Nice article. I am just reading the Netezza paper.
>
> You don’t appear to have debunked the following statement.
>
“Exadata is unable to process this three table join in its MPP tier and instead must inefficiently move all the data required by the calculation across the network to Oracle > RAC.”
>
Not many queries exist where data is only required from two tables. Are Oracle suggesting we need to change the way data is structured to enable best use of Exadata – increasing > TCO significantly?
>
> Thanks & Nice post.

There is a reason that I did not debunk that statement - it did not exist in the original version of Netezza's paper.  It seems they have taken the shopping basket example that I debunked in [my previous post](/2010/08/10/oracle-exadata-and-netezza-twinfin-compared-%E2%80%93-an-engineer%E2%80%99s-analysis/) and replaced it with this one.   Nonetheless lets take a look at Netezza's claim:

> Exadata's storage tier provides Bloom filters to implement simple joins between one large and one smaller table, anything more complex cannot be processed in MPP. Analytical queries commonly require joins more complex than those supported by Exadata. Consider the straightforward case of an international retailer needing insight to the dollar value of sales made in stores located in the UK. This simple SQL query requires a join across three tables - sales, currency and stores.
>
> ``` sql
> select sum(sales_value * exchange_rate) us_dollar_sales
> from sales, currency, stores
> where sales.day = currency.day
> and stores.country = 'UK'
> and currency.country = 'USA'
> ```
> Exadata is unable to process this three table join in its MPP tier and instead must inefficiently move all the data required by the calculation across the network to Oracle RAC.


Before I comment, did you spot the error with the SQL query?  Hint: Count the number of tables and joins.

Now that we can clearly see that Netezza marketing can not write good SQL because this query contains a cross product as there is no JOIN between sales and stores thus the value returned from this query **is not** "the [US] dollar value of sales made in stores located in the UK", it's some other rubbish number.

Netezza is trying to lead you to believe that sending data to the database nodes (running Oracle RAC) is a bad thing, which is most certainly is not.  Let's remember what Exadata is - Smart Storage.  Exadata itself _is not_ an MPP database, so of course it needs to send some data back to the Oracle database nodes where the Oracle database kernel can use Parallel Execution to easily parallelize the execution of this query in an MPP fashion efficiently leveraging all the CPUs and memory of the database cluster.

The reality here is that both Netezza and Oracle will do the JOIN in their respective databases, however, Oracle can push a Bloom filter into Exadata for the STORES.COUNTRY predicate so that the only data that is returned to the Oracle database are rows matching that criteria.

Let's assume for a moment that the query is correctly written with two joins and the table definitions look like such (at least the columns we're interested in):

``` sql
create table sales (
 store_id    number,
 day         date,
 sales_value number
);

create table currency (
 day           date,
 country       varchar2(3),
 exchange_rate number
);

create table stores (
 store_id number,
 country  varchar2(3)
);

select
    sum(sales.sales_value * currency.exchange_rate) us_dollar_sales
from
    sales,
    currency,
    stores
where
    sales.day = currency.day
and sales.store_id = stores.store_id
and stores.country = 'UK'
and currency.country = 'USA';
```

For discussion's sake, let's assume the following:

* There is 1 year (365 days) in the SALES table of billions of rows
* There are 5000 stores in the UK (seems like a realistic number to me)

There is no magic in those numbers, it's just something to add context to the discussion, so don't think I picked them for some special reason.  Could be more, could be less, but it really doesn't matter.

So if we think about the the cardinality for the tables:

* STORES has a cardinality of 5000 rows
* CURRENCY has a cardinality of 365 rows (1 year)

The table JOIN order should be STORES -> SALES -> CURRENCY.

With Exadata what will happen is such:

* Get STORE_IDs from STORE where COUNTRY = 'UK'
* Build a Bloom Filter of these 5000 STORE\_IDs and push them into Exadata
* Scan SALES and apply the Bloom Filter in storage, retuning only rows for UK STORE\_IDs and project only the necessary columns
* JOIN that result to CURRENCY
* Compute the SUM aggregate

All of these operations are performed in parallel using Oracle's Parallel Execution.

Netezza suggests that Exadata can use Bloom filters for only two table joins (1 big, 1 small) and that analytical queries are more complex than that so Exadata can not use a Bloom filter and provide an example to suggest such.  The reality is not only is their example incorrectly written SQL, it also works great with Exadata Bloom filters and it is more than 2 tables!  In addition, it is a great demonstration of efficient and smart data movement as Exadata can smartly filter using Bloom filters and needs to only project a very few columns, thus likely creating a big savings versus sending all the columns/rows from the storage.  Thus Exadata Bloom filters **can work** with complex analytical queries of more than two tables and **efficiently** send data across the network to the Oracle RAC cluster where Parallel Execution will work on the JOINs and aggregation in an MPP manor.  

Now to specifically answer your question: **No, Oracle is not suggesting you need to change your data/queries to support two table joins, Exadata will likely work fine with what you have today**.  And to let you and everyone else in on a little secret: Exadata actually supports applying _**multiple**_ Bloom filters to a table scan (we call this a **Bloom filter list** denoted by the Predicate Information of a query plan by ```SYS_OP_BLOOM_FILTER_LIST```), so you can have multiple JOIN filters being applied in the Exadata storage, so in reality Bloom filters are not even limited to just 2 table JOINs.

Oh well, so much for Netezza competitive marketing.  Just goes to show that Netezza has a very poor understanding how Exadata really works (yet again).
