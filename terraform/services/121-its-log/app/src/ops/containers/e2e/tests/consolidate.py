from pathlib import Path
from .params import PARAMS
import requests
import sys
from .dates import yyyymmdd
from datetime import datetime


def consolidate(PARAMS, kind="daily"):
    now = datetime.now()

    if kind == "daily":
        body = {
            "kind": kind,
            "ymd": yyyymmdd(),
        }
    elif kind == "monthly":
        body = {
            "kind": kind,
            "month": now.month,
            "year": now.year,
        }
    elif kind == "yearly":
        body = {
            "kind": kind,
            "year": now.year,
        }
    elif kind == "full":
        body = {
            "kind": kind,
        }
    else:
        print("🔴 failed to find consolidation kind")
        sys.exit(-1)

    try:
        url = f'{PARAMS.base()}/v1/consolidate'
        res: requests.Response = PARAMS.session().post(url,
                                                       headers=PARAMS.headers(
                                                           "PUPPERADMIN"),
                                                       json=body,
                                                       timeout=PARAMS.get("TIMEOUT"))
        if res.status_code > 399:
            print("consolidate:", res.status_code)
            print(res.text)
            print(body)
            res.close()
            sys.exit(-1)
        if res.status_code >= 200 and res.status_code < 300:
            res.close()
            return res.status_code
        res.close()
    except requests.exceptions.Timeout as e:
        print("🔴 consolidate timed out")
        return 408


def test_consolidate(PARAMS, kind):
    print(f"== test_consolidate {kind}")
    code = consolidate(PARAMS, kind)
    print(f"🟢 test_consolidate {code}")
