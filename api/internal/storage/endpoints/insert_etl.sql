-- name: InsertETL :exec
PREPARE insert_etl AS
  INSERT INTO itslog_etl (
    key_id, name, kind, body
  ) VALUES (
    ?, ?, ?, ?
  )
  ON CONFLICT (name) 
  DO UPDATE SET 
    key_id = EXCLUDED.key_id,
    name = EXCLUDED.name, 
    kind = EXCLUDED.kind,
    body = EXCLUDED.body;