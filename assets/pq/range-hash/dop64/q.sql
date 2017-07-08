set lines 200 trimspool on timing on
exec dbms_workload_repository.create_snapshot
select /* &&1 */
       /*+ parallel (t1, 64) parallel (t2, 64) */
       min (t1.bsns_unit_key + t2.bsns_unit_key),
       max (t1.day_key + t2.day_key),
       avg (t1.day_key + t2.day_key),
       max (t1.bsns_unit_typ_cd),
       max (t2.curr_ind),
       max (t1.load_dt)
from   d31.dwb_rtl_trx t1,
       d31.dwb_rtl_trx t2
where  t1.trx_nbr = t2.trx_nbr;

exec dbms_workload_repository.create_snapshot

