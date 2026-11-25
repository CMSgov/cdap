## Testing this locally
# starlark internal/base/etl/starlark/sum-pocket-change.star

# def query(_, s):
#     return [
#         {"tags": "pocketchange", "value": '{"pennies": 3, "nickels": 5}'}, 
#         ]

def summarize():
    query_rows = query("events", """
    SELECT * from event 
    WHERE 
        json_type(tags, '$') = 'ARRAY' 
        AND 
        -- JSON strings must be in double-quotes when
        -- using the json_contains function.
        -- https://duckdb.org/docs/2.0/data/json/json_functions#json-scalar-functions
        json_contains(tags, '"pocketchange"')
    """)
    sums = {
        "pennies": 0,
        "nickels": 0,
        "dimes": 0,
        "quarters": 0,
    }
    for row in query_rows:
        # Convert the value field from JSON to a dictionary
        d = row["data"]
        # Sum up what we find
        for coin in ["pennies", "nickels", "dimes", "quarters"]:
            if coin in d:
                sums[coin] = sums[coin] + d[coin]
    total = sums["pennies"] + (sums["nickels"] * 5) + (sums["dimes"] * 10) + (sums["quarters"] * 25)
    now = time.now()
    padded_month = ("00" + str(now.month))[-2:]
    padded_day = ("00" + str(now.day))[-2:]
    current_date = "{}-{}-{}".format(now.year, padded_month, padded_day)

    result = [
        {
            "date":  current_date,
            "operation": "total.pocketchange", 
            "data": {"count": total}
        },
        {
            "date": current_date,
            "operation": "total.pocketchange.json", 
            "data": sums}
    ]
    print(result)
    return result

# print(summarize())
