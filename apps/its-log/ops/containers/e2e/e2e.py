import click
from pathlib import Path
from tests import (
    log_create,
    params,
    test_create_etl,
    test_run_etl,
    test_pocketchange,
    wait_for_healthcheck,
    test_sequential_event_logging,
    test_parallel_inserts

)
from http import HTTPStatus
import sys
import time


# Waits until the its-log healthcheck returns a good value.
# Useful for debugging


def test_insert_summary(PARAMS):
    pass


@click.command()
@click.option('--env', default="config-local.json", help='Local env')
def main(env):
    # For multiprocessing
    # Becomes global per process
    PARAMS = params.Params(env)

    wait_for_healthcheck(PARAMS)
    test_create_etl(PARAMS, 'sql/sentinel.sql')
    test_run_etl(PARAMS, "sentinel")
    test_create_etl(PARAMS, 'sql/count-total.sql')
    test_run_etl(PARAMS, "count-total")

    test_sequential_event_logging(PARAMS, 1)

    test_create_etl(PARAMS, 'starlark/total-summary-count.star')
    test_run_etl(PARAMS, "total-summary-count")

    # pocketchange inserts data, runs a Starlark ETL,
    # and then fetches the result to check if it is right.
    test_pocketchange(PARAMS)

    # insert_summary tests if we can insert a summary and then
    # read back the value we stored
    test_insert_summary(PARAMS)

    wait_for_healthcheck(PARAMS)
    test_parallel_inserts(PARAMS, 3)

    print("====================")
    print("==     SUCCESS    ==")
    print("====================")


if __name__ in "__main__":
    main()
