INSERT INTO itslog_etl (
  key_id, name, kind, body
) VALUES (
  $key_id, $name, $kind, decode(from_base64($body))
)
