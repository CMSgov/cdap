
from pathlib import Path
from tests import (
    log_create,
    Params,
    PARAMS,
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


def test_insert_summary():
    pass


def main():

    wait_for_healthcheck()
    test_create_etl('sql/sentinel.sql')
    test_run_etl("sentinel")
    test_create_etl('sql/count-total.sql')
    test_run_etl("count-total")

    test_sequential_event_logging(1)

    test_create_etl('starlark/total-summary-count.star')
    test_run_etl("total-summary-count")

    # pocketchange inserts data, runs a Starlark ETL,
    # and then fetches the result to check if it is right.
    test_pocketchange()

    # insert_summary tests if we can insert a summary and then
    # read back the value we stored
    test_insert_summary()

    wait_for_healthcheck()
    test_parallel_inserts(3)


if __name__ in "__main__":
    main()
