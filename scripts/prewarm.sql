-- Run this script following a postgres DB restore in RDS to get data out of
-- lazy loading. On a ~250GB database, this takes around 15 minutes. A VACUUM
-- FULL on the same database takes hours. This script does the following:
--
-- - Runs VACUUM ANALYZE to update postgres stats on relpages, etc.
-- - Prints out the table of relations to be warmed
-- - Enables the pg_prewarm extension if it hasn't been enabled already
-- - Prints out the relation name and number of blocks warmed as it loops
--
-- This script must be run on each database in the cluster. To run with
-- timing in psql:
--   postgres=> \timing
--   postgres=> \c postgres
--   postgres=> \i prewarm.sql

-- Run VACUUM ANALYZE to update postgres stats on relpages, etc.
VACUUM ANALYZE;

-- Create and print out the table of relations to be warmed
DROP TABLE IF EXISTS warmrels;
CREATE TEMP TABLE warmrels AS
  SELECT c.oid, c.relkind, c.relpages, c.relname
  FROM pg_class c
  JOIN pg_user u ON u.usesysid = c.relowner
  WHERE u.usename NOT IN ('rdsadmin', 'rdsrepladmin', ' pg_signal_backend', 'rds_superuser', 'rds_replication')
  AND c.relkind NOT IN ('v', 'I', 'p')
  ORDER BY c.relpages ASC;
SELECT * FROM warmrels;

-- Enable the pg_prewarm extension if it hasn't been enabled already
CREATE EXTENSION IF NOT EXISTS pg_prewarm;

-- Prewarm each relation, printing out the name and number of blocks warmed
DO $$
DECLARE
  rel RECORD;
  numblocks int8;
BEGIN
  FOR rel IN SELECT * FROM warmrels LOOP
    RAISE INFO 'relname: %', rel.relname;
    SELECT pg_prewarm(rel.oid) INTO numblocks;
    RAISE INFO 'numblocks: %', numblocks;
  END LOOP;
END
$$;
