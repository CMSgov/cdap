SELECT 
    "date",
    operation, 
    tags,
    "data",
  FROM summary
  WHERE 
    "date" = $date
    AND
    operation LIKE $operation
    AND
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
  ORDER BY id DESC
  LIMIT 1
  ;
