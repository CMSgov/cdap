-- name: GetETL :one
PREPARE get_etl AS
  SELECT name, kind, body, last_run
  FROM itslog_etl
  WHERE
    name = ?
  LIMIT 1;