SELECT 
    'count.total' as operation,
    '' as tags,
    '' as value,
    (SELECT count(*) from itslog_events) as count
    
;