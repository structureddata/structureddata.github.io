set lines 200 trimspool on timing on
exec dbms_workload_repository.create_snapshot
select /* &&1 */
/*+ parallel (t1, 16) parallel (t2, 16) */
 min(t1.BSNS_UNIT_KEY + t2.BSNS_UNIT_KEY ) ,
 max(t1.DAY_KEY + t2.DAY_KEY),
 avg(t1.DAY_KEY + t2.DAY_KEY),
 max(t1.BSNS_UNIT_TYP_CD  ),
 max(t2.CURR_IND) ,
 max(t1.LOAD_DT)
from
  retail.DWB_RTL_TRX   t1 ,
  retail.DWB_RTL_TRX   t2
where t1.TRX_NBR = t2.TRX_NBR
;
exec dbms_workload_repository.create_snapshot

