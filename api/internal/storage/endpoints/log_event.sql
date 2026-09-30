-- name: LogEvent :one
PREPARE log_event AS
INSERT INTO itslog_events (
  timestamp, key_id, cluster, tags, value
) VALUES (
  $_timestamp, $_key_id, $_cluster, $_tags, $_value
)
RETURNING id
;
