## Testing this locally
# starlark internal/base/etl/starlark/total-summary-count.star

# def query(table, s):
#     print(s)
#     return [{"tags": "something.v3", "count": 3 }, {"tags": "another.v2", "data": {"count": 8} }]

def summarize():
    query_rows = query("summary", "SELECT * from summary")
    total = 0
    for row in query_rows:
        total += len(row["operation"])
    now = time.now()
    padded_month = ("00" + str(now.month))[-2:]
    padded_day = ("00" + str(now.day))[-2:]
    current_date = "{}-{}-{}".format(now.year, padded_month, padded_day)

    result = [
        {
            "date": current_date,
            "operation": "total.summary", 
            "data": {"count": total}
        },
    ]
    return result
