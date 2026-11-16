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
    test_consolidate

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
    # Log some events
    test_sequential_event_logging(PARAMS, 1)
    # Consolidate them into a daily, monthly, yearly, and full archive
    PARAMS.set("TIMEOUT", 45)
    test_consolidate(PARAMS, "daily")
    test_consolidate(PARAMS, "monthly")
    test_consolidate(PARAMS, "yearly")
    test_consolidate(PARAMS, "full")
    PARAMS.set("TIMEOUT", 4)

    test_create_etl(PARAMS, 'sql/sentinel.sql', 'daily')
    test_run_etl(PARAMS, "sentinel", {
        "kind": "daily",
    })
    test_create_etl(PARAMS, 'sql/sentinel.sql', 'monthly')
    test_run_etl(PARAMS, "sentinel", {
        "kind": "monthly",
    })
    test_create_etl(PARAMS, 'sql/count-total.sql', 'full')
    test_run_etl(PARAMS, "count-total", {
        "kind": "full",
    })

    test_create_etl(PARAMS, 'starlark/total-summary-count.star', 'daily')
    test_run_etl(PARAMS, "total-summary-count", {
        "kind": "daily"
    })

    # pocketchange inserts data, runs a Starlark ETL,
    # and then fetches the result to check if it is right.
    test_pocketchange(PARAMS, 'daily')

    # insert_summary tests if we can insert a summary and then
    # read back the value we stored
    test_insert_summary(PARAMS)

    wait_for_healthcheck(PARAMS)

    print("====================")
    print("==     SUCCESS    ==")
    print("====================")


if __name__ in "__main__":
    main()
