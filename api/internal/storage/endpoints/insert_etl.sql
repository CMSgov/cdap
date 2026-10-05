INSERT INTO itslog_etl (
  key_id, name, kind, body
) VALUES (
  $key_id, $name, $kind, decode(from_base64($body))
)
-- ON CONFLICT (name) 
-- DO UPDATE SET 
--   key_id = $key_id,
--   name = $name, 
--   kind = $kind,
--   body = decode(from_base64($body))
