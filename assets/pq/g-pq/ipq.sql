select ts,
BYTES_SENT/1024/1024 MB_SENT,
lag(BYTES_SENT,1) over (order by ts),
BYTES_RCV/1024/1024 MB_RCV ,
lag(BYTES_RCV,1) over (order by ts),
(BYTES_SENT-lag(BYTES_SENT,1) over (order by ts))/1024/1024 diff_senta_mb,
(BYTES_RCV-lag(BYTES_RCV,1) over (order by ts))/1024/1024  diff_rcv_mb
,(ts-lag(ts,1) over (order by ts))+trunc(sysdate)
from grahn.ksxp
where name='ipq'
order by ts
/

