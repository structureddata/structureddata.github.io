---
author: Greg Rahn
comments: true
date: 2011-08-09
layout: post
slug: crowdsourcing-active-sql-monitor-reports
title: Crowdsourcing Active SQL Monitor Reports
wp_id: 1476
wp_categories:
  - 11gR1
  - 11gR2
  - Oracle
---

As my loyal readers will know, I have been a big (maybe BIG) fan of the [SQL Monitor Report](/2008/01/06/oracle-11g-real-time-sql-monitoring-using-dbms_sqltunereport_sql_monitor/) since it's introduction in 11g.  It would not surprise me if I have looked at over 1000 SQL Monitor Reports in the past 4+ years -- so I'm pretty familiar with these bad boys.  Since I find them so valuable (and many customers are now upgrading to 11g), I've decided to do a deep dive into the SQL Monitor Report at both [Oracle OpenWorld 2011](http://www.oracle.com/openworld/index.html) in October and the [UKOUG](http://techandebs.ukoug.org/) in December.  I think I have some pretty interesting and educational examples, but for anyone willing to share Active SQL Monitor Reports from their system, I thought I would extend the possibility to have it publicly discussed at either one of these sessions (or even a future blog post).  Sound cool?  I think so, though I may be slightly biased. 

### The Rules & Requirements

Here are some rules, requirements, restrictions, etc.:

- The SQL Monitor Report requires Oracle Database 11g and the Oracle Database Tuning Pack.
- By sending me your SQL Monitor Report you implicitly grant permission to me to use it however I want (in my sessions, on my blog, on my refrigerator, etc.).
- If you want to scrub it (remove the SQL Text, rename tables, etc.), feel free, but if you make the report unusable, it will end up in the bit bucket.
- I will only consider SQL Monitor Reports that are of type EM or ACTIVE, not TEXT or HTML or XML.
- I prefer the statement uses Parallel Execution, but will accept serial statements nonetheless.
- Active SQL Monitor Reports can be either saved from the EM/DB Console SQL Monitoring page, or via SQL*Plus (see code below).
- Once you save your Active SQL Monitor Report, validate it is functional from your browser (don't send me broken stuff).

In order to participate in this once in a lifetime offer, just email the Active SQL Monitor Report file as an attachment to [sqlmon@structureddata.org](mailto:sqlmon@structureddata.org?subject=Active SQL Monitor Report).  If you are going to be attending my session at either OOW11 or UKOUG11, let me know so if I choose your report I'll notify you so you can bring your friends, significant other, boss, etc.  Thanks in advance!

```
--
-- script to create an Active SQL Monitor Report given a SQL ID
-- 11.2 and newer (EM/ACTIVE types are not in 11.1)
--
set pagesize 0 echo off timing off linesize 1000 trimspool on trim on long 2000000 longchunksize 2000000 feedback off
spool sqlmon_4vbqtp97hwqk8.html

select dbms_sqltune.report_sql_monitor(report_level=>'ALL', type=>'EM', sql_id=>'4vbqtp97hwqk8') monitor_report from dual;

spool off
```