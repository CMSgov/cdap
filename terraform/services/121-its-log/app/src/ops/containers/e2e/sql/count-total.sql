SELECT 
    'count.total' as operation,
    '' as tags,
    json_object('count', (SELECT count(*) from itslog_events)) as data
;