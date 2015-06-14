set termout off long 500000000 longchunksize 500000000 pages 0 timing off echo off verify off
spool &&1..html
select
DBMS_SQLTUNE.REPORT_SQL_MONITOR(
   session_id=>sys_context('userenv','sid'),
   type=>'html',
   report_level=>'ALL') as report
from dual;
spool off
set pages 50000 timing on 

