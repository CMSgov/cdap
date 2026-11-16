from pathlib import Path
from .params import PARAMS
import base64
import requests
import sys

from .dates import yyyymmdd
from datetime import datetime


def get_contents(filename):
    contents = open(filename, 'r').read()
    encoded = base64.b64encode(contents.encode("utf-8")).decode("ascii")
    if len(encoded) % 4 != 0:
        the_length = len(encoded)
        mod = the_length % 4
        encoded = encoded + "="*mod
    return encoded


def create_etl(PARAMS, filename, kind):
    now = datetime.now()

    encoded = get_contents(filename)
    language = "INVALID_DEFAULT"
    if ".sql" in filename:
        language = "sql"
    elif ".star" in filename:
        language = "starlark"
    else:
        print("Bad ETL type")
        sys.exit(-1)

    body = {
        # Sending a superset of values to
        # cover all the possible `kind` values.
        "name": Path(filename).stem,
        "kind": kind,
        "language": language,
        "b64": encoded,
        "ymd": yyyymmdd(),
        "year": now.year,
        "month": now.month,
    }

    try:
        url = f'{PARAMS.base()}/v1/etl/create'
        res: requests.Response = PARAMS.session().post(url,
                                                       headers=PARAMS.headers(
                                                           "PUPPERADMIN"),
                                                       json=body,
                                                       timeout=PARAMS.get("TIMEOUT"))
        if res.status_code > 399:
            print("create_etl:", res.status_code)
            print(res.text)
            res.close()
            sys.exit(-1)
        if res.status_code >= 200 and res.status_code <= 299:
            return res.status_code
        res.close()
    except requests.exceptions.Timeout as e:
        print(e)


def test_create_etl(PARAMS, filename, kind):
    print(f"== test_create_etl {filename}")
    code = create_etl(PARAMS, filename, kind)
    print(f"🟢 test_create_etl {code}")
