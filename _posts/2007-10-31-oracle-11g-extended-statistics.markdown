---
author: Greg Rahn
comments: true
date: 2007-10-31T16:00:31.000Z
layout: post
slug: oracle-11g-extended-statistics
title: 'Oracle 11g: Extended Statistics'
wp_id: 71
wp_id: 37
wp_categories:
  - 11gR1
  - Data Warehousing
  - Execution Plans
  - Optimizer
  - Oracle
  - SQL Tuning
  - Statistics
  - VLDB
wp_tags:
  - 11g
  - CREATE_EXTENDED_STATS
  - DBMS_STATS
  - extended statistics
  - Oracle
  - Statistics
---

In the [Real-World Performance Roundtable, Part 2: The Optimizer, Schema Statistics, SQL Tuning](/presentations.html) at Oracle OpenWorld 2006, I worked an example of how the optimizer can have difficulty estimating the correct cardinality when there is data correlation. (The Zodiac example can be found on pages 46-49 of the presentation.)  In Oracle 11g, there has been some enhancements to help the optimizer deal with data correlation.

### DBMS_STATS.CREATE_EXTENDED_STATS

Previously I blogged about the [11g enhancement to `DBMS_STATS.AUTO_SAMPLE_SIZE`](/2007/09/17/oracle-11g-enhancements-to-dbms_stats/) and the new algorithm for gathering NDV.  One of the other enhancements to `DBMS_STATS` is the [`CREATE_EXTENDED_STATS`](http://download.oracle.com/docs/cd/B28359_01/appdev.111/b28419/d_stats.htm#sthref9835) function.  It is this function that will allow us to tell the Optimizer that two or more columns have data that is correlated.

### Zodiac Calendar Example

Let's turn to the Zodiac calendar example to demonstrate where the functionality of `DBMS_STATS.CREATE_EXTENDED_STATS` can be applied.  As you may know, there is a correlation between the Zodiac Sign and the calendar month.  Below are the Zodiac signs and the corresponding days of the month.

- Aries : March 21 - April 20
- Taurus : April 21 - May 21
- Gemini : May 22 - June 21
- Cancer : June 22 - July 22
- Leo : July 23 -August 21
- Virgo : August 22 - September 23
- Libra : September 24 - October 23
- Scorpio : October 24 - November 22
- Sagittarius : November 23 - December 22
- Capricorn : December 23 - January 20
- Aquarius : January 21 - February 19
- Pisces : February 20- March 20

For this test case I am going to load two tables, `CALENDAR` and `PERSON`.  Below is a description of each.

``` sql
SQL> desc calendar
 Name              Null?    Type
 ----------------- -------- ------------
 DATE_ID           NOT NULL NUMBER(8)
 MONTH             NOT NULL VARCHAR2(16)
 ZODIAC            NOT NULL VARCHAR2(16)

SQL> desc person
 Name              Null?    Type
 ----------------- -------- ------------
 PERSON_ID         NOT NULL NUMBER(10)
 DATE_ID           NOT NULL NUMBER(8)
```

The `CALENDAR` table has 365 rows, one row for every day of the calendar year.  The `PERSON` table has 32,768 rows for each `DAY_ID` (each day of the year) for a total of 11,960,320 rows.

There are a few indexes I'm building on the tables:

- Unique index on `PERSON(PERSON_ID)`
- Unique index on `CALENDAR(DATE_ID)`
- Non-Unique index on `PERSON(DATE_ID)`

Now that the tables loaded and indexes created, it's time to create the [Extended Stats](http://download.oracle.com/docs/cd/B28359_01/appdev.111/b28419/d_stats.htm#sthref9835).  Below is a portion of the documentation.

--------------------------------------------------------------------------------

### CREATE_EXTENDED_STATS Function

This function creates a column statistics entry in the system for a user specified column group or an expression in a table. Statistics for this extension will be gathered when user or auto statistics gathering job gathers statistics for the table. We call statistics for such an extension, "extended statistics". This function returns the name of this newly created entry for the extension.

#### Syntax

``` sql
DBMS_STATS.CREATE_EXTENDED_STATS (
   ownname    VARCHAR2,
   tabname    VARCHAR2,
   extension  VARCHAR2)
 RETURN VARCHAR2;
```

#### Parameters

**_Table 127-8 CREATE_EXTENDED_STATS Function Parameters_**

<table title="CREATE_EXTENDED_STATS Function Parameters" rules="groups" cellspacing="0" summary="This table describes the Parameters of DBMS_STATS.CREATE_EXTENDED_STATS subprogram." width="100%" cellpadding="3" border="1" class="Formal" dir="ltr">
    <tr align="left" valign="top"> Parameter Description </tr>
    <tbody>
        <tr align="left" valign="top">
            <td headers="r1c1-t12" align="left" id="r2c1-t12">ownname</td>
            <td headers="r2c1-t12 r1c2-t12" align="left">Owner name of a table </td>
        </tr>
        <tr align="left" valign="top">
            <td headers="r1c1-t12" align="left" id="r3c1-t12">tabname</td>
            <td headers="r3c1-t12 r1c2-t12" align="left">Name of the table </td>
        </tr>
        <tr align="left" valign="top">
            <td headers="r1c1-t12" align="left" id="r4c1-t12">extension</td>
            <td headers="r4c1-t12 r1c2-t12" align="left">Can be either a column group or an expression. Suppose the specified table has two column `c1`, `c2`. An example column group can be "(`c1`, `c2`)" and an example expression can be "(`c1` + `c2`)". </td>
        </tr>
    </tbody>
</table>

#### Return Values

This function returns the name of this newly created entry for the extension.

--------------------------------------------------------------------------------


Since there is a correlation between the `MONTH` and `ZODIAC` columns in the `CALENDAR` table, the column group for the extended statistics will be `(MONTH, ZODIAC)`.

Here is the command to create the extended stats: `SELECT DBMS_STATS.CREATE_EXTENDED_STATS(USER, 'CALENDAR', '(MONTH, ZODIAC)') FROM DUAL;`

Now that we have the extended stats definition created, it's time to gather stats.  Here are the commands I'm using to gather stats:

```
BEGIN
 DBMS_STATS.GATHER_TABLE_STATS
 (
  OWNNAME => USER
 ,TABNAME => 'CALENDAR'
 ,ESTIMATE_PERCENT => NULL
 ,METHOD_OPT => 'FOR ALL COLUMNS SIZE SKEWONLY'
 );
END;
/
BEGIN
 DBMS_STATS.GATHER_TABLE_STATS
 (
  OWNNAME => USER
 ,TABNAME => 'PERSON'
 ,ESTIMATE_PERCENT => NULL
 );
END;
/
```

Lets look at the column stats on the two tables:

``` sql
SELECT
   TABLE_NAME,
   COLUMN_NAME,
   NUM_DISTINCT as NDV,
   NUM_BUCKETS,
   SAMPLE_SIZE,
   HISTOGRAM
FROM
   USER_TAB_COL_STATISTICS
ORDER BY 1,2;

TABLE_NAME COLUMN_NAME                    NDV      NUM_BUCKETS SAMPLE_SIZE HISTOGRAM
---------- ------------------------------ -------- ----------- ----------- ---------------
CALENDAR   DATE_ID                             365         254         365 HEIGHT BALANCED
CALENDAR   MONTH                                12          12         365 FREQUENCY
CALENDAR   SYS_STUWHPY_ZSVI_W3#C$I3EUUYB4       24          24         365 FREQUENCY
CALENDAR   ZODIAC                               12          12         365 FREQUENCY
PERSON     DATE_ID                             365           1    11960320 NONE
PERSON     PERSON_ID                      11960320           1    11960320 NONE
```

As you can see, there are column statistics gathered on column group of `CALENDAR.(MONTH, ZODIAC)` represented by the `SYS_STUWHPY_ZSVI_W3#C$I3EUUYB4` column.

### The Moment of Truth

Will the extended statistics be enough to give the optimizer the information it needs to estimate an accurate number of rows?  Let's test it by running three test cases:

- How many people have a birth month of May?
- How many people have a Zodiac sign of Taurus?
- How many people have a birth month of May and a Zodiac sign of Taurus?

Each query is run with a `/*+ gather_plan_statistics */` hint followed by `SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));` The goal is to have the E-Rows (Optimizer Estimated Rows) be statistically accurate of the A-Rows (Actual Rows).

Below is the output from `DBMS_XPLAN.DISPLAY_CURSOR` for each of the three test cases.

```
PLAN_TABLE_OUTPUT
--------------------------------------------------------------------
SQL_ID  55qv2rt3k8b3w, child number 0
-------------------------------------
select /*+ gather_plan_statistics */  count(*)
from  person p ,calendar c
where p.date_id = c.da te_id and month = 'may'

Plan hash value: 1463406140

--------------------------------------------------------------------
| Id  | Operation           | Name      | Starts | E-Rows | A-Rows |
--------------------------------------------------------------------
|   1 |  SORT AGGREGATE     |           |      1 |      1 |      1 |
|   2 |   NESTED LOOPS      |           |      1 |   1015K|   1015K|
|*  3 |    TABLE ACCESS FULL| CALENDAR  |      1 |     31 |     31 |
|*  4 |    INDEX RANGE SCAN | PERSON_N1 |     31 |  32768 |   1015K|
--------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("MONTH"='may')
   4 - access("P"."DATE_ID"="C"."DATE_ID")



PLAN_TABLE_OUTPUT
--------------------------------------------------------------------
SQL_ID  8y54wtmy228r0, child number 0
-------------------------------------
select /*+ gather_plan_statistics */ count(*)
from  person p ,calendar c
where p.date_id = c.date_id and zodiac = 'taurus'

Plan hash value: 1463406140

--------------------------------------------------------------------
| Id  | Operation           | Name      | Starts | E-Rows | A-Rows |
--------------------------------------------------------------------
|   1 |  SORT AGGREGATE     |           |      1 |      1 |      1 |
|   2 |   NESTED LOOPS      |           |      1 |   1015K|   1015K|
|*  3 |    TABLE ACCESS FULL| CALENDAR  |      1 |     31 |     31 |
|*  4 |    INDEX RANGE SCAN | PERSON_N1 |     31 |  32768 |   1015K|
--------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter("ZODIAC"='taurus')
   4 - access("P"."DATE_ID"="C"."DATE_ID")


PLAN_TABLE_OUTPUT
--------------------------------------------------------------------
SQL_ID  8ntkxs4ztb2rz, child number 0
-------------------------------------
select /*+ gather_plan_statistics */ count(*)
from  person p ,calendar c
where p.date_id = c.date_id and zodiac = 'taurus' and month = 'may'

Plan hash value: 1463406140

--------------------------------------------------------------------
| Id  | Operation           | Name      | Starts | E-Rows | A-Rows |
--------------------------------------------------------------------
|   1 |  SORT AGGREGATE     |           |      1 |      1 |      1 |
|   2 |   NESTED LOOPS      |           |      1 |    688K|    688K|
|*  3 |    TABLE ACCESS FULL| CALENDAR  |      1 |     21 |     21 |
|*  4 |    INDEX RANGE SCAN | PERSON_N1 |     21 |  32768 |    688K|
--------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - filter(("ZODIAC"='taurus' AND "MONTH"='may'))
   4 - access("P"."DATE_ID"="C"."DATE_ID")
```

### Summary

As demonstrated, adding Extended Statistics and using Histograms allowed the Optimizer to accurately estimate the number of rows, even when there was data correlation.  This is a very useful enhancement to assist the Optimizer when there is known data correlation.
