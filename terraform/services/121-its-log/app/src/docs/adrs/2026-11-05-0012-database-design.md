# database design in its-log

Date: 2026-11-05

## status

Accepted

## decision

A logical database for a "day" will be represented by multiple database files.

## context

its-log is organized around databases-as-files. This is for several reasons.

* Architectural simplicity. We don't have a database server to pay for/maintain.
* Archival simplicity. We can archive data for mandatory retention periods with a simple "copy" operation.

However, file-based databases (SQlite, DuckDB) do not like multiple writers (especially when those writers are in separate operating system processes). If we had multiple its-log instances/containers, there could be contention/errors that result from those instances trying to log simultaneously to the same database file, up to and including file corruption.

It is worth noting that its-log has no central database as a result. It creates database files on-the-fly for events, and as such, there is no centralized "state" in the current design.

## discussion

In the simplest model, events for a given app on a given day are logged to a file named for that day. App ids are tied to the API key, so they are guaranteed to be unique and connected to the correct user/key.

Given an API called NEWBE, and the app id `newbe`, we currently expect database names like

newbe_2026-11-03.duckdb

This has the pattern

[app id]_[date].duckdb

However, if we have two instances logging on the same day, that means the same file will be in contention for writes. We might expand the pattern to

[app id]\_[target]\_*per-instance parts*.duckdb

pupper_instance_0_2026-11-05.duckdb
pupper_instance_1_2026-11-05.duckdb

The `target` will determine what follows.

* `instance` will be followed by an instance id and then a YYYY-MM-DD date, separated by underscores.
* `daily` will be followed by a YYYY-MM-DD date.
* `weekly` will be followed by a week number.
* `monthly` will will be followed by YYYY-MM
* `full` will have no additional information after the target.

This implies a *typing* of database files. All files will contain all tables, but those tables may be populated differently.


### events

Event logging "just works." We end up with multiple database files (one per instance), and some number of events in each table (assuming log requests come in round-robin to the instances).

Event logging has an implicit target of `instance`. The client using its-log does not get to choose where events are logged.

### lifecycle

Because we are managing data in files, and we can split (say) a single day's worth of data over multiple files, having a *lifecycle* can simplify things.

It is possible for DuckDB to query across multiple files. That is, we could (for example) collect data for a given day into as many files as there are instances. This could yield files like this:

```
/data
  | -> appXYZ_0_2026-10-11.duckdb
  | -> appXYZ_1_2026-10-11.duckdb
```

its-log has a notion of archiving data to cold storage. This is because our "hot" storage (in `/data`) is typically more expensive (e.g. EFS), and the "cold" storage (in `/archive`) will be an S3 Files filesystem or similar (10x cheaper). To minimize cost, we want our data in cold storage.

its-log, every night shortly after midnight, automatically does the following:

1. Copy the "hot" instance database files to the archive. (This is for safety.)
2. Open a DB file in `/archive` with the name `[app_id]_[target].duckdb`
3. Select over the entire `events` table from a glob of the "hot" instance data (e.g. `[app_id]_*_[target]`)
4. Insert into the archive `events` table.

This consolidates instance DBs into a single `daily` DB. From there:

In this way, we end up with a filesystem that looks like:

```
/data
  | -> appXYZ_0_2026-10-12.duckdb
  | -> appXYZ_1_2026-10-12.duckdb
/archive
  | -> appXYZ_instance_0_2026-10-11.duckdb
  | -> appXYZ_instance_1_2026-10-11.duckdb
  | -> appXYZ_daily_2026-10-11.duckdb
  | -> appXYZ_weekly_43.duckdb
  | -> appXYZ_weekly_44.duckdb
  | -> appXYZ_monthly_2026-10.duckdb
  | -> appXYZ_full.duckdb
```

Again, this is an automatic action taken by its-log. The client does not have control over the process of producting `daily` databases.

The `weekly` and `monthly` targets are generated in the same way; every week or month, its-log consolidates the `events` **and** `summary` tables from the `daily` databases into a single file. A `full` target is generated on a weekly basis from all `weekly` targets.

### etls

This works for writing *events* to databases. But, we also run ETL processes on that data. An ETL process can read from either the events table or the summary table, and it returns rows (in the case of SQL) or JSON (in the case of Starlark) representing the operation, tags, and data (JSON) that we want to write to the summary table.

ETLs are created and are run against a `target`. Valid targets include:

1. `daily`: 2026-11-02
2. `weekly`: 44
3. `monthly`: 10
4. `full`














DuckDB allows for querying across database files in two ways.

**Explicitly attach databases**. It is possible to say `ATTACH filename AS db`. We could ATTACH every database to the instance, query across those tables, and then DETACH the databases. DuckDB raises the question of file descriptors (e.g. this means leaving many files open), which may, or may not, become a problem. (Fargate has a 65K limit. This may not be an issue.)

**Glob**. A second way would be to glob. 

```
SELECT x FROM read_duckdb('/data/[app id]-*.duckdb', table_name = 'itslog_events');
```

would glob all of the databases for a given app, and allow us to query against the itslog_events table in all of those database files.

We will need the following information to run an ETL:

* app id: we have this from the API key
* target: target we want to run the ETL on
  
Targets help define when/where the ETL will run. We cannot run ETLs on the current data collection; all ETL actions take place on archived data.

1. `YYYY-MM-DD` runs an ETL on a specific date. its-log will look in `/archive` for the file(s) matching this date, and virtualize an `events` table for those files.
2. 

Dates might be `YYYY-MM-DD`, or `today`, or `yesterday`. In any of these cases, we would be dealing with multiple tables. When running these queries, we always create a virtual table called `events`, which is a `VIEW` mapped to the `itslog_events` table(s). For example:

```
DROP VIEW IF EXISTS events;
CREATE VIEW events
AS (SELECT * FROM read_duckdb('pupper_[app-id]_*_2026-11-02.duckdb', table_name='events'));
```

This would select all of the instance databases from 11/02. 

In this way, developers can test locally against a single table, but know that their queries will run on the server as expected.

### etls over archived data


## related documents


