from .params import PARAMS
from .create_etl import create_etl
from .log_create import log_create
from .run_etl import run_etl
from .summary_read import summary_read

import requests
import json
import sys
import time


def test_pocketchange(PARAMS):
    NUMBER_OF_PENNIES = 100
    existing_pennies = 0

    create_etl(PARAMS, 'starlark/sum-pocket-change.star')
    run_etl(PARAMS, "sum-pocket-change")
    js = summary_read(PARAMS, "total.pocketchange")

    if js and "data" in js and "count" in js["data"]:
        existing_pennies = js["data"]["count"]
        print(f"🟢 found {existing_pennies} pennies pre-existing")
    else:
        print(f"🟢 found no pennies")

    for i in range(NUMBER_OF_PENNIES):
        res: requests.Response = log_create(
            PARAMS, None, ["pocketchange"], {"pennies": 1})
        if res.status_code > 399:
            res.close()
            sys.exit(-1)
    res.close()

    # We have to wait until the buffer flushes to count the pennies.
    time.sleep(3)

    run_etl(PARAMS, "sum-pocket-change")
    js = summary_read(PARAMS, "total.pocketchange")

    if js["data"]["count"] == NUMBER_OF_PENNIES + existing_pennies:
        print(f"🟢 found {NUMBER_OF_PENNIES + existing_pennies} pennies")
    else:
        print("🔴 bad penny")
