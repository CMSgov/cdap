INSERT INTO etl (
  key_id, name, language, destination, body
) VALUES (
  $key_id, $name, $language, $destination, decode(from_base64($body))
)
ON CONFLICT (name) DO UPDATE SET 
  key_id = EXCLUDED.key_id,
  name = EXCLUDED.name,
  language = EXCLUDED.language,
  destination = EXCLUDED.destination,
  body = EXCLUDED.body
;
