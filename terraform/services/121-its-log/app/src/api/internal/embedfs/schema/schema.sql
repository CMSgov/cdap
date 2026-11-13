-- SCHEMA
-- Tells the engine to skip parameter replacement
-- Makes no sense on schemas

-- its-log version / schema version
-- date
-- current github hash?
CREATE TABLE IF NOT EXISTS metadata (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE SEQUENCE IF NOT EXISTS events_id_seq START 1;
CREATE TABLE IF NOT EXISTS event (
    -- automatically provided by the SQLite engine
    id BIGINT PRIMARY KEY DEFAULT nextval('events_id_seq') NOT NULL,
    inserted DATETIME DEFAULT now() NOT NULL, 
    -- so we know what key performed the operation
    key_id TEXT NOT NULL,
    -- cluster is useful for a related set of events
    cluster TEXT,
    -- some apps have multiple internal sources
    tags JSON NOT NULL,
    data JSON
);

CREATE SEQUENCE IF NOT EXISTS summary_id_seq START 1;

CREATE TABLE IF NOT EXISTS summary (
    id INTEGER PRIMARY KEY default nextval('summary_id_seq') NOT NULL,
    inserted DATETIME DEFAULT now() NOT NULL,
    key_id TEXT NOT NULL,
    date DATE DEFAULT now() NOT NULL,
    operation TEXT NOT NULL,
    tags JSON,
    data JSON NOT NULL,
    UNIQUE (date, operation, tags)
);

CREATE SEQUENCE IF NOT EXISTS etl_id_seq START 1;

CREATE TABLE IF NOT EXISTS etl (
    id INTEGER PRIMARY KEY DEFAULT nextval('etl_id_seq') NOT NULL,
    inserted DATETIME DEFAULT now() NOT NULL,
    key_id TEXT NOT NULL,
    -- Any DB should only have one ETL of a given name
    name TEXT NOT NULL,
    language TEXT NOT NULL,
    destination TEXT DEFAULT 'summary',
    body TEXT NOT NULL,
    UNIQUE(name)
);

CREATE SEQUENCE IF NOT EXISTS activity_id_seq START 1;

CREATE TABLE IF NOT EXISTS activity (
    id INTEGER PRIMARY KEY default nextval('activity_id_seq') NOT NULL,
    inserted DATETIME DEFAULT now() NOT NULL,
    key_id TEXT NOT NULL,
    etl_name TEXT NOT NULL,
    activity TEXT NOT NULL
);