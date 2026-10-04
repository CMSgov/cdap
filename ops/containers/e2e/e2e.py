import base64
import json
import os
from pathlib import Path
import requests
import time

ENV = {}


def load_env():
    global ENV
    with open("config.json", "r") as f:
        ENV = json.load(f)


def base():
    return f'http://{ENV["ITSLOG_SERVE_HOST"]}:{ENV["ITSLOG_SERVE_PORT"]}'


def headers(type):
    return {
        "x-api-key": ENV[f"ITSLOG_APIKEY_{type}"]["key"]
    }


def wait_for_healthcheck():
    url = f'{base()}/v1/health'
    alive = False
    while not alive:
        try:
            res = requests.get(url, timeout=2)
            if res.status_code > 399:
                print('Waiting for healthcheck...')
                time.sleep(3)
        except:
            print('Waiting for healthcheck...')
            time.sleep(2)
        else:
            alive = True


def log_create(cluster, tags, value):
    url = f'{base()}/v1/log/create'
    body = {}
    if len(str(cluster)) > 1:
        body["cluster"] = str(cluster)
    if len(str(value)) > 1:
        body["value"] = str(value)
    body["tags"] = tags
    res = requests.post(url, headers=headers("PUPPERLOG"), json=body)
    return res


LESS_THAN_BUFFER = 3
MORE_THAN_BUFFER = 3


def test_sequential_event_logging():
    # Create one event
    res = log_create("", ["v1"], "")
    if res.status_code > 399:
        print("test_sequential_event_logging:", res.text)
        os.exit(-1)
    time.sleep(2)
    # Create 100 events, pass values
    for i in range(LESS_THAN_BUFFER):
        res = log_create("", ["v2", "centi"], i)
        if res.status_code > 399:
            print("test_sequential_event_logging:", res.text)
            os.exit(-1)
    # Create 5000 events, which will require 3 buffer flushes
    # Pass values and clusters
    for i in range(MORE_THAN_BUFFER):
        res = log_create(f"c{i % 1000}", ["v3", "milli"], i)
        if res.status_code > 399:
            print("test_sequential_event_logging:", res.text)
            os.exit(-1)
    res.close()
    # There should now be 5101 events in the events table.


def test_create_etl(filename):
    contents = open(filename, 'r').read()
    url = f'{base()}/v1/etl/create'
    encoded = base64.b64encode(contents.encode("utf-8")).decode("ascii")
    print("length", len(encoded))
    if len(encoded) % 4 != 0:
        the_length = len(encoded)
        mod = the_length % 4
        encoded = encoded + "="*mod
    print("length", len(encoded))

    body = {
        "name": Path(filename).stem,
        "kind": "sql",
        "body": encoded,
        "date": "today"
    }
    res = requests.post(url, headers=headers("PUPPERADMIN"), json=body)
    print("posted:", res.request.body)
    if res != 200:
        print("test_create_etl:", res.status_code, res.text)
    res.close()


def main():
    load_env()
    wait_for_healthcheck()
    test_sequential_event_logging()
    test_create_etl('sql/sentinel.sql')
    # test_create_etl('sql/count-total.sql')


if __name__ in "__main__":
    main()
