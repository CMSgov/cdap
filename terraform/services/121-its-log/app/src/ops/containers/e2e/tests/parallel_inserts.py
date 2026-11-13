from .params import Params, PARAMS
from .sequential_events import create_N_events
from .run_etl import run_etl
from .summary_read import summary_read
from .create_etl import create_etl
import time
from multiprocessing import Pool, Process

# It is worth noting that while this "works,"
# it is unclear whether it is doing what we think
# it should be doing. May need a rewrite.


def init_process():
    pass


def test_parallel_inserts(PARAMS, N):
    print(f"test_parallel_inserts {N}")
    pools = []
    for _ in range(N):
        pools.append(Pool(processes=N, initializer=init_process))
    # p1 = Pool(processes=N, initializer=init_process)
    # p2 = Pool(processes=N, initializer=init_process)

    run_etl(PARAMS, "count-total")
    js = summary_read(PARAMS, "count.total")
    initial_events = -1
    if js and "data" in js and "count" in js["data"]:
        initial_events = js["data"]["count"]
        print(f"🔵 {initial_events} found")
    else:
        print(js)

    params = []
    for ndx in range(N):
        params.append([PARAMS, N*1000, "", ["P", "parallel"], ""])
        pools[ndx].map_async(create_N_events, params)
        pools[ndx].map_async(create_etl, [PARAMS, 'sql/sentinel.sql'] * N * N)
    for ndx in range(N):
        pools[ndx].close()
    for ndx in range(N):
        pools[ndx].join()

    # r1 = p1.map_async(create_N_events, params)
    # p1.close()
    # r2 = p2.map_async(create_etl, [PARAMS, 'sql/sentinel.sql'] * N * N)
    # p2.close()
    # p1.join()
    # p2.join()

    time.sleep(PARAMS.get("TIMEOUT"))

    run_etl(PARAMS, "count-total")
    js = summary_read(PARAMS, "count.total")
    final_events = -1
    if js and "data" in js and "count" in js["data"]:
        final_events = js["data"]["count"]
        print(f"🔵 {final_events} found")
    total = final_events - initial_events
    print(f"parallel initial {initial_events} {final_events} {total}")
