---
author: Greg Rahn
comments: true
date: 2007-10-16
layout: post
slug: how-to-display-high_valuelow_value-columns-from-user_tab_col_statistics
title: How to Display HIGH_VALUE/LOW_VALUE Columns from USER_TAB_COL_STATISTICS
wp_id: 31
wp_categories:
  - Execution Plans
  - Optimizer
  - Oracle
  - Statistics
  - Troubleshooting
---

Here is some code to create a function to display the `HIGH_VALUE`/`LOW_VALUE` columns from `USER_TAB_COL_STATISTICS` which are stored as `RAW` datatypes.

[https://github.com/gregrahn/oracle_scripts/blob/master/display_raw.sql](https://github.com/gregrahn/oracle_scripts/blob/master/display_raw.sql)

For example:

```
-- ===================================
-- = Example query using display_raw =
-- ===================================

col low_val for a32
col high_val for a32
col data_type for a32
select
   a.column_name,
   display_raw(a.low_value,b.data_type) as low_val,
   display_raw(a.high_value,b.data_type) as high_val,
   b.data_type
from
   user_tab_col_statistics a, 
   user_tab_cols b
where
   a.table_name='ORDERS' and
   a.table_name=b.table_name and
   a.column_name=b.column_name
/

COLUMN_NAME          LOW_VAL          HIGH_VAL         DATA_TYPE
-------------------- ---------------- ---------------- ---------
ORGANIZATION_ID      00D000000000062  00D300000000tgk  CHAR
UG_ID                00500000000008U  00GD0000000mBda  CHAR
USERS_ID             005000000000063  00G30000000mBcq  CHAR
IS_TRANSITIVE        0                1                CHAR
SUPPRESS_RULES       0                1                CHAR
```
