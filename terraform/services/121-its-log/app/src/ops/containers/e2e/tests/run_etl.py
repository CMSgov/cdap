from .params import PARAMS
import requests
import sys

from .dates import yyyymmdd
from datetime import datetime


def run_etl(PARAMS, etl, body={}):
    now = datetime.now()

    url = f'{PARAMS.base()}/v1/etl/run'
    default = {
        "name": etl,
        "ymd": yyyymmdd(),
        "year": now.year,
        "month": now.month,
        "destination": "summary"
    }
    body = default | body

    try:
        res: requests.Response = PARAMS.session().post(url,
                                                       headers=PARAMS.headers(
                                                           "PUPPERADMIN"),
                                                       json=body,
                                                       timeout=PARAMS.get("TIMEOUT"))
        if res.status_code in [200, 201]:
            return
        if res.status_code > 399:
            print("run_etl:", res.status_code, res.text)
            res.close()
            sys.exit(-1)
        res.close()
    except requests.exceptions.Timeout as e:
        print(e)


def test_run_etl(PARAMS, etl, body={}):
    print(f"== test_run_etl {etl}")
    return run_etl(PARAMS, etl, body)
