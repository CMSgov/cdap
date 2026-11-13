SELECT name, language, destination, body
FROM etl
WHERE
  name = $name
ORDER BY id DESC 
LIMIT 1;