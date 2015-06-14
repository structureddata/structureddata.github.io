---
author: Greg Rahn
comments: true
date: 2007-04-23T12:00:52.000Z
layout: post
slug: upscaling-your-database-application-performance-cursor-management
title: 'Upscaling Your Database Application Performance: Cursor Management'
wp_id: 13
wp_categories:
  - Performance
  - Troubleshooting
---

In my previous post, [Bind Variables](/2007/03/26/upscaling-your-database-application-performance-bind-variables/), I discussed why using bind variables is one of the most important fundamentals in engineering scalable database applications.  I briefly touch on the point that cursor management is also very important.  In this post I will go into why this is important, demonstrating by example.

As a precursor to this post, you may want to read the section "Analyzing Cursor Operations" in [Designing Applications For Performance And Scalability](http://www.oracle.com/technology/deploy/performance/pdf/designing_applications_for_performance_and_scalability.pdf).

### The Performance Issue

A Java application is making a database call which consists of an anonymous block of PL/SQL containing insert statements.  The text of this PL/SQL block looks like such:

``` sql
DECLARE
BEGIN
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO)
    VALUES (:1, :2, :3, :4, SYSDATE, :5, :6, :7);
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO)
    VALUES (:8, :9, :10, :11, SYSDATE, :12, :13, :14);
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO)
    VALUES (:15, :16, :17, :18, SYSDATE, :19, :20, :21);
  INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:22, :23, :24);
  INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:25, :26, :27);
END;
```

As the application executes this insert block again and again, the execution time increases until the point that the application server is timing out the database connection.

### Debugging Analysis

The same anonymous PL/SQL block was run with bind variables in SQL*Plus and it did not display any increase in CPU or elapsed time after the same number of calls.

### SQL Trace File

Below is part of a SQL trace file from the Java application session.

```
=====================
PARSING IN CURSOR #2 len=512 dep=0 uid=45 oct=47 lid=45 tim=261783946058 hv=283572372 ad='24e8718c'
DECLARE
BEGIN
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:1, :2, :3, :4, SYSDATE, :5, :6, :7);
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:8, :9, :10, :11, SYSDATE, :12, :13, :14);
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:15, :16, :17, :18, SYSDATE, :19, :20, :21);
  INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:22, :23, :24);
  INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:25, :26, :27);
END;
END OF STMT
PARSE #2:c=0,e=853,p=0,cr=0,cu=0,mis=1,r=0,dep=0,og=1,tim=261783946053
=====================
PARSING IN CURSOR #5 len=121 dep=1 uid=45 oct=2 lid=45 tim=261783949786 hv=1783440776 ad='2a669628'
INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:B1, :B2, :B3, :B4, SYSDATE, :B5, :B6, :B7)
END OF STMT
PARSE #5:c=0,e=171,p=0,cr=0,cu=0,mis=1,r=0,dep=1,og=1,tim=261783949780
EXEC #5:c=0,e=911,p=2,cr=4,cu=23,mis=1,r=1,dep=1,og=1,tim=261783950888
=====================
PARSING IN CURSOR #6 len=121 dep=1 uid=45 oct=2 lid=45 tim=261783951074 hv=1783440776 ad='2a669628'
INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:B1, :B2, :B3, :B4, SYSDATE, :B5, :B6, :B7)
END OF STMT
PARSE #6:c=0,e=58,p=0,cr=0,cu=0,mis=0,r=0,dep=1,og=1,tim=261783951070
EXEC #6:c=0,e=77,p=0,cr=1,cu=3,mis=0,r=1,dep=1,og=1,tim=261783951266
=====================
PARSING IN CURSOR #7 len=121 dep=1 uid=45 oct=2 lid=45 tim=261783951338 hv=1783440776 ad='2a669628'
INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:B1, :B2, :B3, :B4, SYSDATE, :B5, :B6, :B7)
END OF STMT
PARSE #7:c=0,e=18,p=0,cr=0,cu=0,mis=0,r=0,dep=1,og=1,tim=261783951334
EXEC #7:c=0,e=37,p=0,cr=1,cu=3,mis=0,r=1,dep=1,og=1,tim=261783951475
=====================
PARSING IN CURSOR #8 len=60 dep=1 uid=45 oct=2 lid=45 tim=261783951671 hv=2406633223 ad='24fbe7c4'
INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:B1, :B2, :B3)
END OF STMT
PARSE #8:c=0,e=145,p=0,cr=0,cu=0,mis=1,r=0,dep=1,og=1,tim=261783951667
EXEC #8:c=0,e=7255,p=2,cr=4,cu=22,mis=1,r=1,dep=1,og=1,tim=261783959040
=====================
PARSING IN CURSOR #9 len=60 dep=1 uid=45 oct=2 lid=45 tim=261783959234 hv=2406633223 ad='24fbe7c4'
INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:B1, :B2, :B3)
END OF STMT
PARSE #9:c=0,e=60,p=0,cr=0,cu=0,mis=0,r=0,dep=1,og=1,tim=261783959229
EXEC #9:c=0,e=60,p=0,cr=1,cu=3,mis=0,r=1,dep=1,og=1,tim=261783959405
EXEC #2:c=0,e=13165,p=4,cr=11,cu=54,mis=1,r=1,dep=0,og=1,tim=261783959474
=====================
PARSING IN CURSOR #10 len=512 dep=0 uid=45 oct=47 lid=45 tim=261783961860 hv=283572372 ad='24e8718c'
DECLARE
BEGIN
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:1, :2, :3, :4, SYSDATE, :5, :6, :7);
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:8, :9, :10, :11, SYSDATE, :12, :13, :14);
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:15, :16, :17, :18, SYSDATE, :19, :20, :21);
  INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:22, :23, :24);
  INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:25, :26, :27);
END;
END OF STMT
PARSE #10:c=0,e=142,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=1,tim=261783961853
=====================
PARSING IN CURSOR #11 len=121 dep=1 uid=45 oct=2 lid=45 tim=261783962232 hv=1783440776 ad='2a669628'
INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:B1, :B2, :B3, :B4, SYSDATE, :B5, :B6, :B7)
END OF STMT
PARSE #11:c=0,e=23,p=0,cr=0,cu=0,mis=0,r=0,dep=1,og=1,tim=261783962228
EXEC #11:c=0,e=111,p=0,cr=1,cu=3,mis=0,r=1,dep=1,og=1,tim=261783962450
=====================
PARSING IN CURSOR #12 len=121 dep=1 uid=45 oct=2 lid=45 tim=261783962542 hv=1783440776 ad='2a669628'
INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:B1, :B2, :B3, :B4, SYSDATE, :B5, :B6, :B7)
END OF STMT
PARSE #12:c=0,e=16,p=0,cr=0,cu=0,mis=0,r=0,dep=1,og=1,tim=261783962538
EXEC #12:c=0,e=44,p=0,cr=1,cu=3,mis=0,r=1,dep=1,og=1,tim=261783962689
=====================
PARSING IN CURSOR #13 len=121 dep=1 uid=45 oct=2 lid=45 tim=261783962755 hv=1783440776 ad='2a669628'
INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:B1, :B2, :B3, :B4, SYSDATE, :B5, :B6, :B7)
END OF STMT
PARSE #13:c=0,e=13,p=0,cr=0,cu=0,mis=0,r=0,dep=1,og=1,tim=261783962751
EXEC #13:c=0,e=36,p=0,cr=1,cu=3,mis=0,r=1,dep=1,og=1,tim=261783962891
=====================
PARSING IN CURSOR #14 len=60 dep=1 uid=45 oct=2 lid=45 tim=261783962958 hv=2406633223 ad='24fbe7c4'
INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:B1, :B2, :B3)
END OF STMT
PARSE #14:c=0,e=15,p=0,cr=0,cu=0,mis=0,r=0,dep=1,og=1,tim=261783962954
EXEC #14:c=0,e=36,p=0,cr=1,cu=3,mis=0,r=1,dep=1,og=1,tim=261783963092
=====================
PARSING IN CURSOR #15 len=60 dep=1 uid=45 oct=2 lid=45 tim=261783963158 hv=2406633223 ad='24fbe7c4'
INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:B1, :B2, :B3)
END OF STMT
PARSE #15:c=0,e=15,p=0,cr=0,cu=0,mis=0,r=0,dep=1,og=1,tim=261783963154
EXEC #15:c=0,e=36,p=0,cr=1,cu=3,mis=0,r=1,dep=1,og=1,tim=261783963293
EXEC #10:c=0,e=1231,p=0,cr=5,cu=15,mis=0,r=1,dep=0,og=1,tim=261783963346
=====================
PARSING IN CURSOR #16 len=512 dep=0 uid=45 oct=47 lid=45 tim=261783970060 hv=283572372 ad='24e8718c'
DECLARE
BEGIN
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:1, :2, :3, :4, SYSDATE, :5, :6, :7);
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:8, :9, :10, :11, SYSDATE, :12, :13, :14);
  INSERT INTO EMP (EMPNO, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO) VALUES (:15, :16, :17, :18, SYSDATE, :19, :20, :21);
  INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:22, :23, :24);
  INSERT INTO DEPT (DEPTNO, DNAME, LOC) VALUES (:25, :26, :27);
END;
END OF STMT
PARSE #16:c=0,e=71,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=1,tim=261783970054
=====================
```

The Java code that executes this PL/SQL looks something like:

``` java
public void execPLSQL(Connection conn) throws SQLException {
   PreparedStatement ps;
   ps = conn.prepareStatement(plsqlText);
   bindData(ps);
   ps.execute();
}
```

For those of you who are not familiar with Java/JDBC this function:

- instantiates a new cursor
- binds the values to the cursor
- executes the cursor

### Root Cause Analysis 

If you look a the SQL trace file you will notice that the cursor numbers keep increasing in value even though the exact same SQL is executed again and again. This is because the Java code block opens a new cursor each time it is called.  The open cursors keep accumulating until the connection is closed.  This is commonly referred to as a cursor leak.  The [Closing the ResultSet and Statement Objects](http://download-west.oracle.com/docs/cd/B19306_01/java.102/b14355/basic.htm#i1006632) section of the [Oracle JDBC Developer's Guide and Reference](http://download-west.oracle.com/docs/cd/B19306_01/java.102/b14355/toc.htm) states:
<blockquote>If you do not explicitly close the ResultSet and Statement objects, serious memory leaks could occur. You could also run out of cursors in the database.</blockquote>

### Solution

The cursor leak can be resolved by explicitly closing the PreparedStatement object. While this resolves the immediate problem, in my opinion there are bigger issues.  Even with the explicit close, the execPLSQL routine is inefficient because it opens, binds, executes, then closes the cursor each time it is called (and this function is called many times).  The insert statements were put into an anonymous PL/SQL block as result of an enhancement request to move the code from using literal values to using bind values.  By wrapping the insert statements in the anonymous PL/SQL block it does reduce the number of round trips to the database.  While the intention was good, the implementation can be better.  In fact, JDBC has this functionality built into it.   The [Oracle JDBC Developer's Guide and Reference](http://download-west.oracle.com/docs/cd/B19306_01/java.102/b14355/toc.htm) contains an entire section on [update batching](http://download-west.oracle.com/docs/cd/B19306_01/java.102/b14355/oraperf.htm#i1056232).  As an added benefit, using batching will leverage the array interface as well.

### Summary

As demonstrated by example, poor cursor management can lead to serious performance issues with both the application and database.  Java database developers need to understand if they open a Statement or ResultSet, they should explicitly close it as well.  At any time one can query to find out how many open cursors each session has with this query:

``` sql
select a.value, s.username, s.sid, s.serial#
from v$sesstat a, v$statname b, v$session s
where a.statistic# = b.statistic#  and s.sid=a.sid and
b.name = 'opened cursors current';
```
