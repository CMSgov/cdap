INSERT INTO etl (
  key_id, name, kind, body
) VALUES (
  $key_id, $name, $kind, decode(from_base64($body))
)
ON CONFLICT (name) DO UPDATE SET 
  key_id = EXCLUDED.key_id,
  name = EXCLUDED.name,
  kind = EXCLUDED.kind,
  body = EXCLUDED.body
;
