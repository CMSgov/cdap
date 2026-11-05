-- its-log version / schema version
-- date
-- current github hash?
CREATE TABLE IF NOT EXISTS itslog_metadata (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE SEQUENCE IF NOT EXISTS itslog_events_id_seq START 1;
CREATE TABLE IF NOT EXISTS itslog_events (
    -- automatically provided by the SQLite engine
    id BIGINT PRIMARY KEY DEFAULT nextval('itslog_events_id_seq') NOT NULL,
    inserted DATETIME DEFAULT now() NOT NULL, 
    -- so we know what key performed the operation
    key_id TEXT NOT NULL,
    -- cluster is useful for a related set of events
    cluster TEXT,
    -- some apps have multiple internal sources
    tags TEXT NOT NULL,
    data JSON
);

CREATE SEQUENCE IF NOT EXISTS itslog_summary_id_seq START 1;

CREATE TABLE IF NOT EXISTS itslog_summary (
    id INTEGER PRIMARY KEY default nextval('itslog_summary_id_seq') NOT NULL,
    inserted DATETIME DEFAULT now() NOT NULL,
    key_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    tags TEXT,
    data JSON NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS itslog_consolidated_id_seq START 1;
CREATE TABLE IF NOT EXISTS itslog_consolidated (
    id INTEGER PRIMARY KEY default nextval('itslog_consolidated_id_seq') NOT NULL,
    inserted DATETIME DEFAULT now() NOT NULL,
    key_id TEXT NOT NULL,
    date DATE NOT NULL,
    operation TEXT NOT NULL,
    tags TEXT,
    data JSON NOT NULL
);

-- See https://stackoverflow.com/questions/22699409/sqlite-null-and-unique
-- We want NULL values to count towards uniqueness here.
-- Seems like it might work for DuckDB, too.
-- CREATE UNIQUE INDEX IF NOT EXISTS summary_ndx ON itslog_summary 
--     (date, operation, IFNULL(tags, 'index_default'), IFNULL(value, 'index_default'));

CREATE SEQUENCE IF NOT EXISTS itslog_etl_id_seq START 1;

CREATE TABLE IF NOT EXISTS itslog_etl (
    id INTEGER PRIMARY KEY DEFAULT nextval('itslog_etl_id_seq') NOT NULL,
    inserted DATETIME DEFAULT now() NOT NULL,
    key_id TEXT NOT NULL,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    body TEXT NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS itslog_activity_id_seq START 1;

CREATE TABLE IF NOT EXISTS itslog_activity (
    id INTEGER PRIMARY KEY default nextval('itslog_activity_id_seq') NOT NULL,
    inserted DATETIME DEFAULT now() NOT NULL,
    key_id TEXT NOT NULL,
    etl_name TEXT NOT NULL,
    activity TEXT NOT NULL
);