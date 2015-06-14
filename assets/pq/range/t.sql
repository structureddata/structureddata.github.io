break on snap_id skip 1
compute sum of DIFF_RECEIVED_MB on SNAP_ID
compute sum of DIFF_SENT_MB on SNAP_ID

select * from (
select
  snap_id, instance_number,
  round((BYTES_SENT     -lag(BYTES_SENT,1)      over (order by instance_number,snap_id))/1024/1024) diff_sent_mb,
  round((BYTES_RECEIVED -lag(BYTES_RECEIVED,1)  over (order by instance_number,snap_id))/1024/1024) diff_received_mb
from dba_hist_ic_client_stats
where name='ipq'
and snap_id between 910 and 917
order by snap_id,instance_number
)
where snap_id in (911,913,915,917)
and DIFF_RECEIVED_MB>10
/
