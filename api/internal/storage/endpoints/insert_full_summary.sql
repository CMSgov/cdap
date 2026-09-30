-- name: InsertFullSummary :exec
PREPARE insert_full_summary AS
INSERT INTO itslog_summary (
  last_run, key_id, date, operation, tags, value, count, hash
  ) VALUES (
  $last_run, $key_id, $date, $operation, $tags, $value, $count, $hash
  )
  ON CONFLICT (date, operation, tags, value) 
  DO UPDATE SET 
    date = EXCLUDED.date,
    operation = EXCLUDED.operation, 
    tags = EXCLUDED.tags,
    value = EXCLUDED.value
    ;