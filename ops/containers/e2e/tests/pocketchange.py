from tests.params import PARAMS
from tests.create_etl import test_create_etl
from tests.log_create import log_create
from tests.run_etl import test_run_etl

import requests


def test_pocketchange():
    global PARAMS
    for i in range(100):
        res: requests.Response = log_create(None, ["pocketchange"], json.dumps({
            "pennies": 1
        }))
        if res.status_code > 399:
            print(res.text)
            res.close()
            sys.exit(-1)
    res.close()
    test_create_etl('starlark/sum-pocket-change.star')
    test_run_etl("sum-pocket-change")
