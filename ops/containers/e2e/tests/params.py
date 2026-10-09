import json
import requests

# For multiprocessing
# Becomes global per process
PARAMS = None

# Params class is so that we can initialize it
# per process in the multiprocessing library.


class Params:
    def __init__(self):
        with open("config.json", "r") as f:
            self.params = json.load(f)
        self.params["TIMEOUT"] = 4
        self.params["LESS_THAN_BUFFER"] = 5
        self.params["MORE_THAN_BUFFER"] = 5
        # Need to use a session, or requests will run out of sockets.
        self.params["session"] = requests.Session()

    def base(self):
        return f'http://{self.params["ITSLOG_SERVE_HOST"]}:{self.params["ITSLOG_SERVE_PORT"]}'

    def headers(self, type):
        return {
            "x-api-key": self.params[f"ITSLOG_APIKEY_{type}"]["key"]
        }

    def session(self):
        return self.params["session"]

    def get(self, key):
        return self.params[key]
