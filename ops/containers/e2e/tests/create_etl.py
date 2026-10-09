from pathlib import Path
from tests.params import PARAMS
import base64
import requests


def test_create_etl(filename):
    global PARAMS
    print(f"test_create_etl {filename}")
    contents = open(filename, 'r').read()
    url = f'{PARAMS.base()}/v1/etl/create'
    encoded = base64.b64encode(contents.encode("utf-8")).decode("ascii")
    if len(encoded) % 4 != 0:
        the_length = len(encoded)
        mod = the_length % 4
        encoded = encoded + "="*mod

    if ".sql" in filename:
        kind = "sql"
    elif ".star" in filename:
        kind = "starlark"
    else:
        kind = "BAD_ETL_TYPE"

    body = {
        "name": Path(filename).stem,
        "kind": kind,
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
            sys.exit(-1)
        res.close()
    except requests.exceptions.Timeout as e:
        print(e)
