INSERT INTO itslog_activity
  (key_id, etl_id, etl_name, activity)
  VALUES
  ($key_id, $etl_id, $etl_name, $activity)
RETURNING 0;