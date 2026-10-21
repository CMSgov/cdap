# endpoint sql

The endpoint SQL statements for DuckDB are all **PREPARE**d at launch time. 

1. `its-log` wakes up
2. A query comes in, and the DB is created.
3. All of the endpoint SQL files are read from the embedded FS, and PREPAREd into `Statement` structs
4. The statement for the requested endpoint is evaluated against the params

Subsequent calls short-circuit the load. That is, the PREPAREd statements are held for the duration of the session, so that we get the most performant possible version of the SQL for inserting/etc.

See `SetupDB` in `operations.go` for more.