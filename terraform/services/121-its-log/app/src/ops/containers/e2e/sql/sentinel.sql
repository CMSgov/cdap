SELECT 
    NOW()::DATE as date,
    'sentinel.test' as operation,
    to_json(['no', 'tag', 'backs']) as tags,
    json_object('life', 42) as data
;

