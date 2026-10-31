SELECT 
    date, 
    operation, 
    tags,
    data
  FROM itslog_summary
  WHERE 
    tags LIKE $tags
    AND
    operation LIKE $operation
  ORDER BY id DESC
  LIMIT 1
  ;