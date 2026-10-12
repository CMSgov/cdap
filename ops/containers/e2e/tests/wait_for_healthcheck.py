from .params import PARAMS
import time


def wait_for_healthcheck(PARAMS):
    url = f'{PARAMS.base()}/v1/health'
    alive = False
    while not alive:
        try:
            print(f'Waiting for healthcheck: {url}')
            res = PARAMS.session().get(url, timeout=PARAMS.get("TIMEOUT"))
            if res.status_code > 399:
                time.sleep(3)
            res.close()
        except:
            print(f'Retrying healthcheck: {url}')
            time.sleep(2)
        else:
            alive = True
            res.close()
