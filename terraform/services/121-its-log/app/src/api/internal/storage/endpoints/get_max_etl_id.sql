-- On the first run, we have to handle the case where nothing comes back.
-- The coalesce handles that case.
SELECT id from itslog_etl 
WHERE 
    name = $name 
ORDER BY id DESC
LIMIT 1;