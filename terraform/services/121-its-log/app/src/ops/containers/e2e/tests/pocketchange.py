from .params import PARAMS
from .create_etl import create_etl
from .log_create import log_create
from .run_etl import run_etl
from .summary_read import summary_read
from .consolidate import consolidate

import requests
import json
import sys
import time


def test_pocketchange(PARAMS, kind):
    NUMBER_OF_PENNIES = 10
    existing_pennies = 0

    create_etl(PARAMS, 'starlark/sum-pocket-change.star', kind)
    run_etl(PARAMS, "sum-pocket-change", {
        "kind": "daily",
    })
    js = summary_read(PARAMS, "total.pocketchange", {})

    if js and "data" in js and "count" in js["data"]:
        existing_pennies = js["data"]["count"]
        print(f"🟢 found {existing_pennies} pennies pre-existing")
    else:
        print(f"🟢 found no pennies")

    counter = 0
    for _ in range(NUMBER_OF_PENNIES):
        counter += 1
        res: requests.Response = log_create(
            PARAMS, None, ["pocketchange"], {"pennies": 1})
        if res.status_code > 399:
            print("🔴 failed to insert penny")
            res.close()
            sys.exit(-1)
    res.close()
    print(f"🔵 added {counter} pennies")

    # We have to wait until the buffer flushes to count the pennies.
    print("🔵 waiting for the pennies")
    time.sleep(3)

    # And, we have to re-consolidate, because the data is not in the summary table.
    consolidate(PARAMS, "daily")
    # Which means the DB gets deleted, so we need to re-load the ETLs.
    create_etl(PARAMS, 'starlark/sum-pocket-change.star', kind)

    # Re-run the ETL to update the count
    run_etl(PARAMS, "sum-pocket-change", {
        "kind": "daily",
    })

    js = summary_read(PARAMS, "total.pocketchange", {})

    found = js["data"]["count"]
    expected = NUMBER_OF_PENNIES + existing_pennies
    if found == expected:
        print(f"🟢 found {NUMBER_OF_PENNIES + existing_pennies} pennies")
    else:
        print("🔴 bad penny")
