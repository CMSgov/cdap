
from multiprocessing import Pool, Process
from pathlib import Path
from tests import (
    log_create,
    Params,
    PARAMS,
    test_create_etl,
    test_run_etl,
    test_pocketchange
)
from http import HTTPStatus
import base64
import json
import os
import requests
import sys
import time


# Waits until the its-log healthcheck returns a good value.
# Useful for debugging


def wait_for_healthcheck():
    global PARAMS
    url = f'{PARAMS.base()}/v1/health'
    alive = False
    while not alive:
        try:
            res = PARAMS.session().get(url, timeout=PARAMS.get("TIMEOUT"))
            if res.status_code > 399:
                print('Waiting for healthcheck...')
                time.sleep(3)
            res.close()
        except:
            print('Waiting for healthcheck...')
            time.sleep(2)
        else:
            alive = True
            res.close()

# Creates log events


# Creates many log events


def test_sequential_event_logging(id):
    global PARAMS
    print(f"test_sequential_event_logging: {id}")
    # Create one event
    res = log_create("", ["v1"], "")
    if res.status_code == HTTPStatus.OK:
        print(f"🟢 {res.status_code} created 1 event")
    else:
        print("test_sequential_event_logging:", res.text)
        res.close()
        sys.exit(-1)

    time.sleep(2)
    # Create 100 events, pass values
    all_ok = True
    N = PARAMS.get("LESS_THAN_BUFFER")
    for i in range(N):
        res = log_create("", ["v2", "centi"], i)
        if res.status_code != HTTPStatus.OK:
            all_ok = False
            print("test_sequential_event_logging:", res.text)
            res.close()
    if all_ok:
        print(f"🟢 created {N} events")
    else:
        print("🔴 FAILURE in test_sequential_event_logging")
        sys.exit(-1)
    # Create 5000 events, which will require 3 buffer flushes
    # Pass values and clusters
    all_ok = True
    N = PARAMS.get("MORE_THAN_BUFFER")
    for i in range(N):
        res = log_create(f"c{i % 1000}", ["v3", "milli"], i)
        if res.status_code != HTTPStatus.OK:
            print("test_sequential_event_logging:", res.text)
            res.close()
            sys.exit(-1)
    res.close()
    if all_ok:
        print(f"🟢 created {N} events")
    else:
        print("🔴 FAILURE in test_sequential_event_logging")
        sys.exit(-1)
    # There should now be 5101 events in the events table.

# Loads an ETL


# Runs an ETL


def init_process():
    global PARAMS
    PARAMS = Params()


def test_parallel_inserts(N):
    print(f"test_parallel_inserts {N}")
    p1 = Pool(processes=N, initializer=init_process)
    p2 = Pool(processes=N, initializer=init_process)
    r1 = p1.map_async(test_sequential_event_logging, range(0, N))
    p1.close()
    time.sleep(3)
    r2 = p2.map_async(test_create_etl, ['sql/sentinel.sql'] * N * N)
    p2.close()
    p1.join()
    p2.join()


def test_insert_summary():
    pass


def main():

    wait_for_healthcheck()
    test_sequential_event_logging(1)
    test_create_etl('sql/sentinel.sql')
    test_create_etl('sql/count-total.sql')
    test_run_etl("sentinel")
    test_run_etl("count-total")
    test_create_etl('starlark/total-summary-count.star')
    test_run_etl("total-summary-count")

    # pocketchange inserts data, runs a Starlark ETL,
    # and then fetches the result to check if it is right.
    test_pocketchange()

    # insert_summary tests if we can insert a summary and then
    # read back the value we stored
    test_insert_summary()

    # wait_for_healthcheck()
    # test_parallel_inserts(3)


if __name__ in "__main__":
    main()
