-- name: UpdateLastRun :exec
PREPARE update_last_run AS
  UPDATE itslog_etl
    SET 
      last_run = epoch(now()) 
  WHERE 
    name = ?
;