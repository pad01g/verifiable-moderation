from starkware.crypto.signature.signature import (
    private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)

from verimod import (generate_key_pair, generate_blocks, make_initial_state, make_final_state)

import argparse
from http.server import (HTTPServer, BaseHTTPRequestHandler)
from urllib.parse import (urlparse, parse_qs)
import json
import sys
import logging

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

def parse_args():
    parser = argparse.ArgumentParser(description='run server with options.')
    parser.add_argument('--config', type=str, default="config.json", help='config location')
    # parser.add_argument('--state', type=str, default="state.json", help='state file location')

    args = parser.parse_args()
    return args

def check_category_elements_child(pubkey, category_elements_child):
    for element in category_elements_child:
        if element["pubkey"] == pubkey:
            return True
        else:
            child_result = check_category_elements_child(pubkey, element["category_elements_child"])
            if child_result:
                return True

    return False

class CustomHTTPRequestHandler(BaseHTTPRequestHandler):

    def __init__(self, *args, **kwargs):
        logging.info("Initialization")
        print("Initializing server")
        sys.stdout.flush()
        try:
            self.args = parse_args()
            config_file = self.args.config
            # @todo make initial state not here, run only once
            d = {}
            with open(config_file) as f:
                d = json.load(f)
            self.initial_state = d['initial_state']
            self.blocks = d['blocks']
            self.final_state , _ = make_final_state(self.initial_state, self.blocks) 
            self.state = []
            for key, value in d.items():
                if "state" in key:
                    self.state.append(value)
            self.state.append(self.final_state)
        except Exception as e:
            logging.error(f"Error: No state file found. Exception: {e}")
            print("Error: No state file found")
            raise e
        print("Initial state: ", self.initial_state)
        print("Final state: ", self.final_state)
        super().__init__(*args, **kwargs)

    # check if requested data satisfies condition
    def do_GET(self):
        logging.info("Received GET request.")
        self.send_response(200)
        self.send_header('Content-type', 'text/plain; charset=utf-8')
        self.end_headers()
        # print("self.path:", self.path)
        sys.stdout.flush()
        # query state and respond here
        try:
            parsed = urlparse(self.path)
            params = parse_qs(parsed.query)

            category_type = params["category_type"][0]
            pubkey = params["pubkey"][0]

            result = False
            for state in self.state:
                for category in state["state"]["all_category"]:
                    if category["data"]["category_type"] == category_type:
                        print("category found")
                        category_elements_child = category["data"]["category_elements_child"]
                        exists = check_category_elements_child(pubkey, category_elements_child)
                        if exists:
                            result = True
                            print("Correct category exits")
                            break
                        else:
                            print("Correct category does not exit")

        except Exception as e:
            logging.error(f"Error: No state file found. Exception: {e}")
            print("Error: No state file found")
            raise e
            pass
        ret = json.dumps({"result": result})
        self.wfile.write(ret.encode('utf-8'))

    # add block data to memory
    def do_POST(self):
        print("POST")
        logging.info("Received Post request.")
        sys.stdout.flush()
        # update state by applying blocks here
        try:
            content_length = int(self.headers['content-length'])
            print("reading")
            sys.stdout.flush()
            body = self.rfile.read(content_length).decode('utf-8')
            new_block_json = json.loads(body)
            new_block = new_block_json["block"]
        except Exception as e:
            logging.error(f"Error: No state file found. Exception: {e}")
            print("Error: Invalid block")
            raise e
            pass
        print("new_block:", new_block)
        sys.stdout.flush()
        try:
            newstate = []
            for state in self.state:
                print("state:", type(state))
                print("state:", state)
                try:
                    final_state, final_hash = make_final_state(state, [new_block])
                    newstate.append(final_state)
                except Exception as e:
                    print("Error: Invalid signature")
            self.state = newstate

            # write state to json file
        except Exception as e:
            logging.error(f"Error: No state file found. Exception: {e}")
            print("Error: Invalid block")
            raise e
            pass

        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        response = {"result": "ok"}
        self.wfile.write(json.dumps(response).encode('utf-8'))

def run_server():
    httpd = HTTPServer(('0.0.0.0', 8000), CustomHTTPRequestHandler)
    logging.info("Server started on port 8000")
    print("Server started on")
    httpd.serve_forever()


def main():
    run_server()

main()