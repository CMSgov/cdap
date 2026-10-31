SELECT name, kind, body
FROM itslog_etl
WHERE
  name = $name
ORDER BY id DESC 
LIMIT 1;