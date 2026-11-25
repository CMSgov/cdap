SELECT 
    NOW()::DATE as date,
    'count.total' as operation,
    '' as tags,
    json_object('count', (SELECT count(*) from event)) as data
;