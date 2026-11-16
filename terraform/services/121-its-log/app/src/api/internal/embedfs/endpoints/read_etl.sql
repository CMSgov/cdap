SELECT name, language, body
FROM etl
WHERE
  name = $name
ORDER BY id DESC 
LIMIT 1;