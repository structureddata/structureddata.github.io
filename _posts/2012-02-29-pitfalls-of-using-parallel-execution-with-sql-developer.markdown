---
author: Greg Rahn
comments: true
date: 2012-02-29T18:00:50.000Z
layout: post
slug: pitfalls-of-using-parallel-execution-with-sql-developer
title: Pitfalls of Using Parallel Execution with SQL Developer
wp_id: 1722
wp_categories:
  - Oracle
  - Parallel Execution
wp_tags:
  - Bugs
  - Parallel Execution
  - SQL Developer
---

_[This post was originally published on 2012/02/29 and was hidden shortly thereafter.  I'm un-hiding it as of 2012/05/30 with some minor edits.]_

Many Oracle Database users like tools with GUI interfaces because they add features and functionality that are not easily available from the command line interfaces like SQL*Plus.  One of the more popular tools from my experiences is [Oracle SQL Developer](http://www.oracle.com/technetwork/developer-tools/sql-developer/overview/index.html) in part because it's a free tool from Oracle.  Given SQL Developer's current design (as of version 3.1.07.42), some issues frequently show up when using it with Oracle Databases with Parallel Execution.  SQL Developer also contains a bug that exacerbates this issue as well.

### The Issue
The crux of the issue with SQL Developer (and possibly other similar tools) and Parallel Execution comes down to how the application uses cursors.  By default, SQL Developer has the array fetch size set to 50.  This means that for any cursor SQL Developer opens for scolling, it will fetch the first 50 rows and when you scroll to the bottom of those rows in a grid, it will fetch the next 50 rows and so on.  The array size can be controlled by going into _Properties_ and changing _Database_ -> _Advanced_ -> _SQL Array Fetch Size_ which allows for a max setting of 500 rows.  This is good in the sense that the JDBC application can fetch an array of rows with a single JDBC database call, however, using this approach with Parallel Execution, the PX servers used for this cursor will not be released until the cursor is canceled or the last row is fetched.  Currently the only way to force reading until the end of cursor in SQL Developer is to issue a Control+End in the data grid.  As a result, any action that uses Parallel Execution and has not fetched all the rows or is not canceled/closed, will squat those Parallel Execution resources and prevent them from being used by other users.  If enough users have open cursors backed by Parallel Execution, then it is possible that it could consume all of the Parallel Execution servers and will result in Parallel Execution requests being forced to Serial Execution because resources are not available, even if the system is completely idle.

### The SQL Developer Bug
When experimenting with SQL Developer for this blog post I also found and filed a bug (bug 13706186) because it leaks cursors when a user browses data in a table by expanding _Tables_ (in the left pane), clicking on a table name and then the _Data_ tab.  Unfortunately this bug adds insult to injury if the table is decorated with a parallel degree attribute because the leaked cursors do not release the Parallel Execution servers until the session is closed, thus preventing other sessions from using them.

This bug is easily demonstrated using the SCOTT schema, but any schema or table will do as long as the table has more rows than the array fetch size.  For my example, I'm using a copy of the EMP table, called EMP2, which contains 896 rows and was created using the following SQL:

The steps to demonstrate this issue are as follows:

- Set up the EMP2 table using the above script or equivalent.
- Use SQL Developer to connect to the SCOTT schema or equivalent.
- Expand _Tables_ in the Browser in the left pane.
- Click EMP2.
- Click on the _Data_ tab of EMP2.
- Check the open cursors.
- Close the EMP2 tab in the right pane.
- Check the open cursors.
- Goto Step #4 and repeat.

I'm going to repeat this process two times for a total of three open and close operations.  I'll use this query to show the open cursors for the _Data_ grid query for the EMP2 table (adjust if necessary if you are not using my example):

If we look at the output (scott_emp2_cursors.txt below the EM graphic) from the query we'll see that the first time the EMP2 Data tab is opened, it opens two identical cursors (sql_exec_id 16777216 & 16777217).  After closing the EMP2 Data tab, 16777216 is still open.  The second time the EMP2 Data tab is opened, two more identical cursors are opened (sql_exec_id 16777218 & 16777219).  The third time two more cursors are opened (sql_exec_id 16777220 & 16777221).  After closing the tabs we still see three cursors open (sql_exec_id 16777216, 16777218 & 16777220), each of which are squatting two PX servers.

This behavior can also be seen in 11g Enterprise Manager (or dbconsole) on the SQL Monitoring page by sorting the statements by time -- notice the (leaked cusor) statements with the green spinning pinwheels after all tabs have been closed (all parallel statements are monitored by default).

![Sqlmon Cursor Leak](/assets/sqlmon_cursor_leak.png)

By the way, the cursor leak applies for tables without a parallel degree setting as well, but has more significant impact if the table is parallel because PX servers are a shared resource.

(scott_emp2_cursors.txt below)

<script src="https://gist.github.com/1924923.js"> </script>

### My Thoughts

Obviously the cursor leak is a SQL Developer bug and needs fixing, but in the interim, DBAs should be aware that this behavior can have a global impact because Parallel Execution servers are shared by all database users.  Also, if SQL Developer users are running Parallel Queries and keep the results grid open but do not fetch all the rows by using the Control+End functionality, those Parallel Execution servers will be unavailable for other users to use and could negatively impact other users queries leveraging Parallel Execution. 

Personally I'd like to see a few enhancements to SQL Developer to avoid these pitfalls:

* **Disable Parallel Execution for Table Data browsing.**  

	Browsing data in a table via a scrollable grid is a "small data" problem and does not require the "big data" resources of Parallel Execution.  This could easily be done by adding a NOPARALLEL hint when SQL Developer builds the query string. 

* **Add a property with functionality to read all rows w/o requiring the Control+End command (always fetch until end of cursor) or until a max number or rows are read (or a max amount of memory is used for the result set), then close the cursor.**  

	By fetching until end of cursor or fetching a max number of rows and closing the cursor, the client will release any Parallel Execution resources it may have used.  Obviously fetching all rows could be a problem with large result sets and cause SQL Developer to run out of memory and crash, which would be a bad user experience, but not releasing PX resources can easily lead to many bad user experiences. 

I've seen the issue of potentially large result sets dealt with in other JDBC based GUI tools that connect to parallel databases by the tool appending a "LIMIT X" clause to queries where the user can control the value for "X" in a property setting.  To the best of my knowledge, no other parallel databases support cursors in the way that Oracle does (being able to fetch rows, pause, then resume fetching), so there is no issue there with squatting resources with them (once they start fetching they must continue until the last row is fetched or the statement is canceled).  As of release 11.2, Oracle does not support the LIMIT clause but this functionality could be done in the client by using some some upper limit on "_array fetch size_" _ "_number of fetches_" or wrapping queries with a "select _ from ([query text]) where rownum <= X" or similiar.

There are some "clever" server-side ways to deal with this as well, such as adding a logon trigger that disables parallel query if the V$SESSION.PROGRAM name is "SQL Developer", but a robust, clean client side solution is preferred by myself and likely other DBAs as well.  It's really just a simple matter of programming.

### Summary

When using SQL Developer or similar tools, be aware of the potential to squat Parallel Execution resources if the client tool has open cursors.  Educate your SQL Developer users on how they can play well with others in an Oracle Database using Parallel Execution by closing unneeded tabs with open cursors.  Be aware of the impact of the cursor leak bug in SQL Developer 3.1.07.42 (and possibly previous releases) until it is fixed.

Personally I'd like to see an enhancement to deal with this behavior and I don't think it would require much programming.  It certainly would allow DBAs to feel more confident that SQL Developer is a tool that can be used on production systems and not result in any issues.  What are your thoughts?  Do my enhancement requests seem reasonable and warranted?
