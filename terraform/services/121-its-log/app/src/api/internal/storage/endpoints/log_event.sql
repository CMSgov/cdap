-- NOTE: this does not get used.
-- Under DuckDB, we use an Appender for performance.
-- This is a direct-to-db write from memory. It is 
-- faster for large number of sequential inserts, which we 
-- do whenever we are logging events.
INSERT INTO itslog_events (
  inserted, key_id, cluster, tags, value
) VALUES (
  $inserted, $key_id, $cluster, $tags, $value
)