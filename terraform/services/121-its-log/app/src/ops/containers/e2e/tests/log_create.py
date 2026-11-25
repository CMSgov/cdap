from .params import PARAMS


def log_create(PARAMS, cluster, tags, data):
    url = f'{PARAMS.base()}/v1/log/create'
    body = {}
    if len(str(cluster)) > 1:
        body["cluster"] = str(cluster)

    body["data"] = data
    body["tags"] = tags
    # print("POSTING: " + str(body))
    res = PARAMS.session().post(
        url, headers=PARAMS.headers("PUPPERLOG"), json=body)

    return res
