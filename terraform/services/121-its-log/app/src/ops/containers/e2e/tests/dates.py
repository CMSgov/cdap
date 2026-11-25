from datetime import date, timedelta


def yyyymmdd(offset=0):
    day = (date.today() - timedelta(days=offset))
    return day.strftime("%Y-%m-%d")
