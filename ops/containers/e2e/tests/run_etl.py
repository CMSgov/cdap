from tests.params import PARAMS
import requests
import sys


def test_run_etl(etl, body={}):
    global PARAMS
    print(f"test_run_etl {etl}")
    url = f'{PARAMS.base()}/v1/etl/run/{etl}'
    try:
        res: requests.Response = PARAMS.session().post(url,
                                                       headers=PARAMS.headers(
                                                           "PUPPERADMIN"),
                                                       json=body,
                                                       timeout=PARAMS.get("TIMEOUT"))
        if res.status_code in [200, 201]:
            return
        if res.status_code > 399:
            print("test_run_etl:", res.status_code, res.text)
            print(res.text)
            res.close()
            sys.exit(-1)
        res.close()
    except requests.exceptions.Timeout as e:
        print(e)
