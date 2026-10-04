import base64
import json
from multiprocessing import Pool, Process
import os
from pathlib import Path
import requests
import time

# For multiprocessing

PARAMS = None


class Params:
    def __init__(self):
        with open("config.json", "r") as f:
            self.params = json.load(f)
        self.params["TIMEOUT"] = 4
        self.params["LESS_THAN_BUFFER"] = 100
        self.params["MORE_THAN_BUFFER"] = 5000
        self.params["session"] = requests.Session()

    def base(self):
        return f'http://{self.params["ITSLOG_SERVE_HOST"]}:{self.params["ITSLOG_SERVE_PORT"]}'

    def headers(self, type):
        return {
            "x-api-key": self.params[f"ITSLOG_APIKEY_{type}"]["key"]
        }

    def session(self):
        return self.params["session"]

    def get(self, key):
        return self.params[key]


def wait_for_healthcheck():
    global PARAMS
    url = f'{PARAMS.base()}/v1/health'
    alive = False
    while not alive:
        try:
            res = PARAMS.session().get(url, timeout=2)
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


def log_create(cluster, tags, value):
    url = f'{PARAMS.base()}/v1/log/create'
    body = {}
    if len(str(cluster)) > 1:
        body["cluster"] = str(cluster)
    if len(str(value)) > 1:
        body["value"] = str(value)
    body["tags"] = tags
    res = PARAMS.session().post(
        url, headers=PARAMS.headers("PUPPERLOG"), json=body)
    return res


def test_sequential_event_logging(id):
    print(f"test_sequential_event_logging: {id}")
    # Create one event
    res = log_create("", ["v1"], "")
    if res.status_code > 399:
        print("test_sequential_event_logging:", res.text)
        res.close()
        os.exit(-1)
    time.sleep(2)
    # Create 100 events, pass values
    for i in range(PARAMS.get("LESS_THAN_BUFFER")):
        res = log_create("", ["v2", "centi"], i)
        if res.status_code > 399:
            print("test_sequential_event_logging:", res.text)
            res.close()
            os.exit(-1)
    # Create 5000 events, which will require 3 buffer flushes
    # Pass values and clusters
    for i in range(PARAMS.get("MORE_THAN_BUFFER")):
        res = log_create(f"c{i % 1000}", ["v3", "milli"], i)
        if res.status_code > 399:
            print("test_sequential_event_logging:", res.text)
            res.close()
            os.exit(-1)
    res.close()
    # There should now be 5101 events in the events table.


def test_create_etl(filename):
    print(f"test_create_etl {filename}")
    contents = open(filename, 'r').read()
    url = f'{PARAMS.base()}/v1/etl/create'
    encoded = base64.b64encode(contents.encode("utf-8")).decode("ascii")
    if len(encoded) % 4 != 0:
        the_length = len(encoded)
        mod = the_length % 4
        encoded = encoded + "="*mod

    body = {
        "name": Path(filename).stem,
        "kind": "sql",
        "body": encoded,
        "date": "today"
    }
    try:
        res = PARAMS.session().post(url,
                                    headers=PARAMS.headers("PUPPERADMIN"),
                                    json=body,
                                    timeout=PARAMS.get("TIMEOUT"))
        if res.status_code > 399:
            print("test_create_etl:", res.status_code)
            print(res.text)
            res.close()
            os.exit(-1)
        res.close()
    except requests.exceptions.Timeout as e:
        print(e)


def test_run_etl(etl, expected):
    print(f"test_run_etl {etl}")
    url = f'{PARAMS.base()}/v1/etl/run/today/{etl}'
    body = {}
    try:
        res = PARAMS.session().post(url,
                                    headers=PARAMS.headers("PUPPERADMIN"),
                                    json=body,
                                    timeout=PARAMS.get("TIMEOUT"))
        if res.status_code > 399:
            print("test_run_etl:", res.status_code, res.text)
            print(res.text)
            res.close()
            os.exit(-1)
        res.close()
    except requests.exceptions.Timeout as e:
        print(e)


def init_process():
    global PARAMS
    PARAMS = Params()


def test_parallel_inserts(N):
    print(f"test_parallel_inserts {N}")
    with Pool(processes=N, initializer=init_process) as pool:
        result = pool.map(test_sequential_event_logging, range(0, N))


def main():
    global PARAMS
    PARAMS = Params()

    wait_for_healthcheck()
    test_sequential_event_logging(1)
    test_create_etl('sql/sentinel.sql')
    test_create_etl('sql/count-total.sql')
    test_run_etl("sentinel", 0)

    wait_for_healthcheck()
    test_parallel_inserts(3)


if __name__ in "__main__":
    main()
