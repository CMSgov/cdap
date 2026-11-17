SELECT 
    operation, 
    tags,
    data,
  FROM summary
  WHERE 
    (
      -- An empty list "matches everything"
      len(cast($tags as JSON)::STRING[]) = 0
      OR
      -- there is an intersection between the 
      -- tag list passed in and the list in the column
      len(list_intersect(
        cast($tags as JSON)::STRING[],
        cast(tags as JSON)::STRING[])
      ) > 0
    )
    AND
    operation LIKE $operation
  ORDER BY id DESC
  LIMIT 1
  ;
