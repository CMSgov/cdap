PREPARE get_etl AS
  SELECT name, kind, body, last_run
  FROM itslog_etl
  WHERE
    name = $name
  LIMIT 1;