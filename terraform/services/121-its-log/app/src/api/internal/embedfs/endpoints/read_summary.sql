SELECT 
    operation, 
    tags,
    "data",
  FROM summary
  WHERE 
    len(list_intersect(
      $tags::JSON::string[],
      cast(tags as JSON)::string[])
      ) > 0
    AND
    operation LIKE $operation
  ORDER BY id DESC
  LIMIT 1
  ;