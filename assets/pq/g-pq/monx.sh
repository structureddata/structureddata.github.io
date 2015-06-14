#!/bin/bash

sqlplus -s / as sysdba <<! >/dev/null
set termout off long 500000000 longchunksize 500000000 pages 0 timing off echo off verify off lines 300 trimspool on
spool $1.xml
select
DBMS_SQLTUNE.REPORT_SQL_MONITOR(
   sql_id=>'$1',
   type=>'xml',
   report_level=>'ALL') as report
from dual;
spool off
set termout on pages 50000 timing on 
exit
!
{
echo '<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
        <base href="http://download.oracle.com/otn_software/"/>
        <script language="javascript" type="text/javascript" src="emviewers/scripts/flashver.js">
            <!--Test flash version-->
        </script>
        <style>
      body { margin: 0px; overflow:hidden }
    </style>
    </head>
    <body scroll="no">
        <script type="text/xml">
            <!--FXTMODEL-->
<report>
'
cat $1.xml
echo '</report>
            <!--FXTMODEL-->
        </script>
        <script language="JavaScript" type="text/javascript" src="emviewers/scripts/loadswf.js">
            <!--Load report viewer-->
        </script>
        <iframe name="_history" frameborder="0" scrolling="no" width="22" height="0">
            <html>
                <head>
                    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1"/>
                    <script type="text/javascript" language="JavaScript1.2" charset="utf-8">
                var v = new top.Vars(top.getSearch(window));
                var fv = v.toString('$_');
              </script>
                </head>
                <body>
                    <script type="text/javascript" language="JavaScript1.2" charset="utf-8" src="emviewers/scripts/document.js">
                        <!--Run document script-->
                    </script>
                </body>
            </html>
        </iframe>
    </body>
</html>
'
} > $1.htm
