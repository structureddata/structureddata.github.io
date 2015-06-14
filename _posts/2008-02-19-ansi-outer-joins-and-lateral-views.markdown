---
author: Greg Rahn
comments: true
date: 2008-02-19T02:00:20.000Z
layout: post
slug: ansi-outer-joins-and-lateral-views
title: ANSI Outer Joins And Lateral Views
wp_id: 55
wp_categories:
  - Execution Plans
  - Optimizer
  - Oracle
  - SQL Tuning
  - Troubleshooting
wp_tags:
  - ANSI outer join
  - lateral view
  - Oracle outer join
  - wrong results
---

A few months ago the [Oracle Optimizer Team](http://optimizermagic.blogspot.com) did a blog post entitled [Outerjoins in Oracle](http://optimizermagic.blogspot.com/2007/12/outerjoins-in-oracle.html).  In the Lateral View section of that post they go through some examples and discuss how a query is transformed with the ANSI outer join syntax.  I thought it would be useful to go through an example that recently came through the Real-World Performance Group.  For simplicity purposes and so that you can play along at home, the test case has been recreated to use EMP and DEPT which have been created and populated via the $ORACLE_HOME/rdbms/admin/utlsampl.sql script.

### The Three Test Cases

Consider the following three SQL statements:

####  Query A: Oracle Outer Join Syntax

```
SELECT d.dname, d.deptno, e.ename
FROM   dept d, emp e
WHERE  d.deptno = e.deptno(+) and
       d.deptno in (10,40)
```

#### Query B: ANSI Outer Join Syntax Version 1

```
SELECT d.dname, d.deptno, e.ename
FROM   dept d LEFT OUTER JOIN emp e
ON     d.deptno = e.deptno
WHERE  d.deptno in (10,40)
```

#### Query C: ANSI Outer Join Syntax Version 2

```
SELECT d.dname, d.deptno, e.ename
FROM   dept d LEFT OUTER JOIN emp e
ON     d.deptno = e.deptno and
       d.deptno in (10,40)
```


Do note the slight difference between the two ANSI versions: Query B has the filter predicate in the WHERE clause,  where Query C has the filter predicate in the ON clause.

### Query Results

#### Query A

```
DNAME              DEPTNO ENAME
-------------- ---------- ----------
ACCOUNTING             10 CLARK
ACCOUNTING             10 KING
ACCOUNTING             10 MILLER
OPERATIONS             40

4 rows selected.
```

#### Query B

```
DNAME              DEPTNO ENAME
-------------- ---------- ----------
ACCOUNTING             10 CLARK
ACCOUNTING             10 KING
ACCOUNTING             10 MILLER
OPERATIONS             40

4 rows selected.
```

####  Query C

```
DNAME              DEPTNO ENAME
-------------- ---------- ----------
ACCOUNTING             10 CLARK
ACCOUNTING             10 KING
ACCOUNTING             10 MILLER
RESEARCH               20
SALES                  30
OPERATIONS             40

6 rows selected.
```

Whoa!  Query C returned 6 rows, while Query A and Query B returned 4 rows.  Must be a wrong results bug...or is it?

### Execution Plans
To start troubleshooting the difference in results sets, lets examine the execution plan of each query.

#### Query A

```
PLAN_TABLE_OUTPUT
---------------------------------------------------------------------------
Plan hash value: 3713469723

---------------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |     9 |   198 |     5  (20)| 00:00:01 |
|*  1 |  HASH JOIN OUTER   |      |     9 |   198 |     5  (20)| 00:00:01 |
|*  2 |   TABLE ACCESS FULL| DEPT |     2 |    26 |     2   (0)| 00:00:01 |
|   3 |   TABLE ACCESS FULL| EMP  |    14 |   126 |     2   (0)| 00:00:01 |
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - access("D"."DEPTNO"="E"."DEPTNO"(+))
   2 - filter("D"."DEPTNO"=10 OR "D"."DEPTNO"=40)
```

#### Query B

```
PLAN_TABLE_OUTPUT
---------------------------------------------------------------------------
Plan hash value: 3713469723

---------------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |     9 |   198 |     5  (20)| 00:00:01 |
|*  1 |  HASH JOIN OUTER   |      |     9 |   198 |     5  (20)| 00:00:01 |
|*  2 |   TABLE ACCESS FULL| DEPT |     2 |    26 |     2   (0)| 00:00:01 |
|   3 |   TABLE ACCESS FULL| EMP  |    14 |   126 |     2   (0)| 00:00:01 |
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - access("D"."DEPTNO"="E"."DEPTNO"(+))
   2 - filter("D"."DEPTNO"=10 OR "D"."DEPTNO"=40)
```

#### Query C

```
PLAN_TABLE_OUTPUT
-----------------------------------------------------------------------------
Plan hash value: 498633241

-----------------------------------------------------------------------------
| Id  | Operation            | Name | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------
|   0 | SELECT STATEMENT     |      |     4 |    80 |    10   (0)| 00:00:01 |
|   1 |  NESTED LOOPS OUTER  |      |     4 |    80 |    10   (0)| 00:00:01 |
|   2 |   TABLE ACCESS FULL  | DEPT |     4 |    52 |     2   (0)| 00:00:01 |
|   3 |   VIEW               |      |     1 |     7 |     2   (0)| 00:00:01 |
|*  4 |    FILTER            |      |       |       |            |          |
|*  5 |     TABLE ACCESS FULL| EMP  |     1 |     9 |     2   (0)| 00:00:01 |
-----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   4 - filter("D"."DEPTNO"=10 OR "D"."DEPTNO"=40)
   5 - filter("D"."DEPTNO"="E"."DEPTNO" AND ("E"."DEPTNO"=10 OR
              "E"."DEPTNO"=40))
```

For some reason (which we need to investigate!), Query C has a different execution plan.  Perhaps this is why the result sets are different.

### The 10053 Trace
Perhaps the 10053 trace from Query C can help us understand why the execution plan is different.  Looking at the trace file we find that Query C has been transformed (the below has been modified for formatting purposes):

```
FROM dept d,
LATERAL(
 (SELECT e.deptno, e.ename
  FROM   emp e
  WHERE  d.deptno=e.deptno and
        (d.deptno=10 or d.deptno=40))
)(+) lv
```

You will notice that the transformation of  Query C contains a Lateral View.  The [Oracle Optimizer Team's](http://optimizermagic.blogspot.com) post on [Outerjoins in Oracle](http://optimizermagic.blogspot.com/2007/12/outerjoins-in-oracle.html) gives us the definition of a Lateral View:
<blockquote>A lateral view is an inline view that contains correlation referring to other tables that precede it in the FROM clause.</blockquote>

What does this mean?  It means that Query C **is not** the same query as Query B and Query A.  Just the slight change of the ANSI syntax causes the meaning of the business question being answered to change!  Query C applies the **deptno in (10,40)** filter to EMP first (returning 3 rows in which deptno=10, there are no deptno=40 rows) and then outer joins that result set to DEPT but **does not** apply the **deptno in (10,40)** filter to DEPT, essentially resulting in this query, which is most likely not what the user had intended:

```
SELECT d.dname, d.deptno, sq.ename
FROM   dept d,
   (SELECT e.deptno, e.ename
    FROM   emp e
    WHERE  e.deptno in (10,40)) sq
WHERE d.deptno=sq.deptno (+)
```

### Summary
Filters specified in the ON clause of outer joins are transformed internally into lateral views and will be applied before the join.  While ANSI join syntax is preferred by some, be certain that your query matches the business question being asked!
