## Testing this locally
# starlark internal/base/etl/starlark/total-summary-count.star

# def query(table, s):
#     print(s)
#     return [{"tags": "something.v3", "count": 3 }, {"tags": "another.v2", "data": {"count": 8} }]

def summarize():
    query_rows = query("summary", "SELECT * from itslog_summary")
    total = 0
    for row in query_rows:
        print("data:", row["data"])
        if "count" in row["data"]:
            print("count is in data")
            print(row["data"])
            total += row["data"]["count"]
        else:
            print("did not find count")
            total += 1

    result = [
        {"operation": "total.summary", "data": {"count": total}},
    ]
    return result

# print(summarize())