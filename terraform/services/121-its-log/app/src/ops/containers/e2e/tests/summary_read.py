from .params import Params, PARAMS

import requests
import sys
from .dates import yyyymmdd


def summary_read(PARAMS, operation, body):
    url = f'{PARAMS.base()}/v1/summary/read'
    body = {
        "operation": operation,
        "kind": "daily",
        "tags": [],
        "ymd": yyyymmdd()
    } | body
    try:
        res: requests.Response = PARAMS.session().post(url,
                                                       headers=PARAMS.headers(
                                                           "PUPPERADMIN"),
                                                       json=body,
                                                       timeout=PARAMS.get("TIMEOUT"))
        if res.status_code in [200, 201]:
            return res.json()
        if res.status_code in [204]:
            print("🔴 empty result set:", res.status_code, res.text)
            res.close()
            sys.exit(-1)
        if res.status_code > 399:
            print("🔴 summary_read:", res.status_code, res.text)
            print(res.text)
            res.close()
            sys.exit(-1)
        res.close()
    except requests.exceptions.Timeout as e:
        print("🔴 request timed out")
        res.close()
        sys.exit(-1)
