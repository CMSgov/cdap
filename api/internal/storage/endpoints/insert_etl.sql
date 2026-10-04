INSERT INTO itslog_etl (
  key_id, name, kind, body
) VALUES (
  $_key_id, $_name, $_kind, decode(from_base64($_body))
)
ON CONFLICT (name) 
DO UPDATE SET 
  key_id = $_key_id,
  name = $_name, 
  kind = $_kind,
  body = decode(from_base64($_body))
