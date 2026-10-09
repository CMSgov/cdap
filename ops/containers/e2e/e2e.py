from tests.params import Params, PARAMS
from tests.log_create import log_create
from tests.pocketchange import test_pocketchange

import base64
import json
from multiprocessing import Pool, Process
import os
from pathlib import Path
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
    if res.status_code > 399:
        print("test_sequential_event_logging:", res.text)
        res.close()
        sys.exit(-1)
    time.sleep(2)
    # Create 100 events, pass values
    for i in range(PARAMS.get("LESS_THAN_BUFFER")):
        res = log_create("", ["v2", "centi"], i)
        if res.status_code > 399:
            print("test_sequential_event_logging:", res.text)
            res.close()
            sys.exit(-1)
    # Create 5000 events, which will require 3 buffer flushes
    # Pass values and clusters
    for i in range(PARAMS.get("MORE_THAN_BUFFER")):
        res = log_create(f"c{i % 1000}", ["v3", "milli"], i)
        if res.status_code > 399:
            print("test_sequential_event_logging:", res.text)
            res.close()
            sys.exit(-1)
    res.close()
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


def summary_read(operation, expected):
    global PARAMS
    print(f"summary_read {operation}")
    url = f'{PARAMS.base()}/v1/summary/read'
    try:
        res: requests.Response = PARAMS.session().post(url,
                                                       headers=PARAMS.headers(
                                                           "PUPPERADMIN"),
                                                       json=body,
                                                       timeout=PARAMS.get("TIMEOUT"))
        if res.status_code in [200, 201]:
            return
        if res.status_code > 399:
            print("test_run_etl:", res.status_code, res.text)
            print(res.text)
            res.close()
            sys.exit(-1)
        res.close()
    except requests.exceptions.Timeout as e:
        print(e)


def test_insert_summary():
    pass


def main():
    global PARAMS
    PARAMS = Params()

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
