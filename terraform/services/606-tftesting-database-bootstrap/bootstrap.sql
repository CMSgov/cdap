DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tftesting_migrator') THEN
    CREATE ROLE tftesting_migrator LOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tftesting_human') THEN
    CREATE ROLE tftesting_human LOGIN;
  END IF;
END $$;

GRANT rds_iam TO tftesting_migrator;
GRANT rds_iam TO tftesting_human;
GRANT CREATE ON DATABASE postgres TO tftesting_migrator;
