# storage abstraction

## tables

its-log stores data in DuckDB database files. Four tables are part of the data model:

* `events` for events that are logged throughout a day
* `summaries` for sumamries of events
* `etls` for storing code that will be used as an ETL action
* `activities` for recording what happened (e.g. running ETLs)

### schema

An `event` carries with it:

* the app_id and key_id doing the logging
  * the app_id should always be the same; key_id may vary
* an insertion timestamp
* a YYYY-MM-DD date for the day the event was captured
* an array of tags
* optional data (JSON)

A `sumamry` carries with it:

* app_id and key_id
* an insertion timestamp
* a YYYY-MM-DD that the ETL applies to
* an operation
* optional tags
* data (JSON)

## database files

### live event files

Databases are stored in files. Events are logged automatically to files given the naming pattern

```
[app id]_instance_[instance]_[YYYY-MM-DD].[extension]
```

The first field is always the app id, and the second is always the *kind* of database file. 

No ETLs are ever run inside of events files.

### sumamry files

`events` files need to be consolidated before they can be processed. Every night, events from multiple instances of its-log are consolidated into a single file representing a day

```
[app id]_daily_[YYYY-MM-DD].[extension]
```

Every day, a `weekly` database is generated with all of the events from the current week. At the end of the week, that database will be "complete" and no longer operated on.

Every day, a `monthly` database is generated with all of the events from the current month. At the end of the month, that database will be "complete."

Every day, a `full` database is generated with all of the events from all of the `daily` databases. It is always regenerated every day.

**Only events are copied forward**. 

This is the smallest unit of data that its-log will run an ETL over. Users may load ETL actions into databases with a type of `daily`, `weekly`, `monthly`, or `full`. 

## modeling

First, we recognize that databases have kinds or types.

```
type DatabaseType int

const (
	Daily DatabaseType = iota
	Weekly
	Monthly
    Full
)
```

All databases will have some functional, invisible needs. We'll call this metadata needed for managing files; these are things that we don't want to expose, generally.

type Metabase struct {
    file_path []string
    file_name string
    lock      sync.Mutex
    context   context.Context
    db        *sql.DB
}

All databases have an app id, key id, and type.

```
type Database struct {
    Metabase
    AppId string
    KeyId string
}
```

The various kinds of database have their own types.

```
type InstanceDatabase struct {
    Database
    InstanceId string
    YYYYMMDD   string
}
```

```
type DailyDatabase struct {
    Database
    YYYYMMDD   string
}
```

```
type WeeklyDatabase struct {
    Database
    YYYY       int
    WeekNumber int
}
```

```
type MonthlyDatabase struct {
    Database
    YYYY         int
    MonthNumber  int
}
```

## actions

Given our model, what can these Databases do?

### .CheckExists()

Given a type, we should be able to check if the file physically exists.

