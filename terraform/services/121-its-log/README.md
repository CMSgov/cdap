# its-log

*It's better than bad, it's good!*

`its-log` is a lightweight event logger and ETL environment for resource-constrained, compliance-burdened environments.

On a Mac M4, `its-log` can sustain logging 8K events/second to a local DuckDB database.

## requirements

For local development:

* VSCode
* Golang extensions
* Docker
* `make` and other related tools

## testing

`make e2e`

This will stand up two Docker containers; one that builds and runs `its-log`, and a second that runs an E2E suite against that container.

After running, the test container should report `SUCCESS`, and both containers will exit.

## debugging its-log

A VS Code debugging bundle is prepared and part of this repository, with all of the envrionment variables required to run. Press `F5` to launch `its-log` under the debugger, and `SHIFT-F5` to halt the debugger (on a Mac).

## testing with Postman

A Postman bundle is included under the `docs` directory. It includes a set of scripts to test results, and can serve as a light E2E test. 

## running its-log

`its-log` can be compiled for multiple architectures.

`make build`

This will build the API locally. It is possible to then run the E2E suite locally (after venv creation and requirements installation).

## model

`its-log` is opinionated, and espouses ways of thinking about logging and subsequent ETL/analysis pipelines.

### runtime events

Applications generate events which are logged. Any given event:

1. **could** belong to a *cluster* of logs
2. **must** be *categorically tagged*
3. **could** have an associated *unique* value

Some events are logged in real-time, and others might be logged via periodic (hourly/daily/weekly) analysis of internal databases.

### ETL

An explicit goal of `its-log` is to move analysis "left" in the pipeline, and reduce the number of moving parts (e.g. GitHub Actions, AWS Lambdas, etc.) involved in transforming raw events into end-user facing information and visualization. To this end, `its-log` encapsulates a light, SQLite-based ETL pipeline infrastructure, allowing data to be processed within the database and, in doing so:

1. Simplify processing at the end of the pipeline (e.g. in Metabase, Superset, QuickSuite, or similar.)
2. Keeping analytical code (and its results) with the data for archived compliance


## the API

The logging endpoints are rooted at `/v1`. So, `/log/create` should be read as `/v1/log/create`.

| HTTP | Endpoint         | Permissions | Desc                                                                                             |
| ---- | ---------------- | ----------- | ------------------------------------------------------------------------------------------------ |
| POST | /log/create      | logging     | Log an event with cluster (optional), tags, value (optional)                                     |
| POST | /log/create/date | admin       | Log an event per above plus a *date*, for creating test scenarios by logging events in the past. |


The ETL and analysis endpoints are

| HTTP | Endpoint         | Permissions | Desc                                                                  |
| ---- | ---------------- | ----------- | --------------------------------------------------------------------- |
| POST | /etl/create      | admin       | Create an ETL action                                                  |
| POST | /etl/run         | admin       | Run an ETL action. Takes optional params in the JSON body.            |
| POST | /sequence/create | admin       | Create an ETL sequence                                                |
| POST | /sequence/run    | admin       | Run a sequence for a given date. Takes optional params like /etl/run. |

For working with the summary table directly

| HTTP | Endpoint      | Permissions | Desc                                                                      |
| ---- | ------------- | ----------- | ------------------------------------------------------------------------- |
| POST | /summary/read | admin       | Read from the summary table; used for testing the results of ETL actions. |


Administrative endpoints include


| HTTP | Endpoint | Permissions | Desc                             |
| ---- | -------- | ----------- | -------------------------------- |
| GET  | /health  | any         | A standard healthcheck endpoint  |
| GET  | /status  | admin       | Get server stats (RAM, GC, etc.) |


## extending its-log

See [DEVELOPMENT.md](docs/DEVELOMENT.md) in `docs`. 

## performance

Performance stress-testing can be run with

`make k6`

This runs K6 in one container, and `its-log` in another.

On an M4 Mac against local NVMe storage, 1200K/sec between containers (HTTP overheads); roughly 70K events/minute.

Containerized performance (2026-10-31)

```
k6-1  |   █ THRESHOLDS 
k6-1  | 
k6-1  |     http_req_duration
k6-1  |     ✓ 'p(95)<15' p(95)=11.06ms
k6-1  | 
k6-1  |     http_req_failed
k6-1  |     ✓ 'rate<0.01' rate=0.00%
k6-1  | 
k6-1  | 
k6-1  |   █ TOTAL RESULTS 
k6-1  | 
k6-1  |     HTTP
k6-1  |     http_req_duration..............: avg=46.37ms min=30.79µs med=2.7ms max=3.83s p(90)=7.64ms p(95)=11.06ms
k6-1  |       { expected_response:true }...: avg=46.37ms min=30.79µs med=2.7ms max=3.83s p(90)=7.64ms p(95)=11.06ms
k6-1  |     http_req_failed................: 0.00%  0 out of 71957
k6-1  |     http_reqs......................: 71957  1199.245313/s
k6-1  | 
k6-1  |     EXECUTION
k6-1  |     vus............................: 21     min=21         max=70
k6-1  |     vus_max........................: 70     min=70         max=70
k6-1  | 
k6-1  |     NETWORK
k6-1  |     data_received..................: 9.9 MB 166 kB/s
k6-1  |     data_sent......................: 16 MB  270 kB/s
k6-1  | 
k6-1  | 
k6-1  | 
k6-1  | 
k6-1  | running (1m00.0s), 00/70 VUs, 0 complete and 70 interrupted iterations
k6-1  | spiking_users ✓ [ 100% ] 01/50 VUs  30s
k6-1  | steady_users  ✓ [ 100% ] 20 VUs     30s
```



## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=navapbc/its-log&type=date&legend=top-left)](https://www.star-history.com/#navapbc/its-log&type=date&legend=top-left)