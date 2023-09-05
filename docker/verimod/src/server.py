from starkware.crypto.signature.signature import (
    pedersen_hash, private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)

from verimod import (generate_key_pair, generate_blocks, make_initial_state, make_final_state)

import argparse
from http.server import (HTTPServer, BaseHTTPRequestHandler)
from urllib.parse import (urlparse, parse_qs)
import json

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
        self.args = parse_args()
        config_file = self.args.config
        # @todo make initial state not here, run only once
        config_file = args.config
        d = {}
        try:
            with open(config_file) as f:
                d = json.load(f)
            self.initial_state = d['initial_state']
            self.blocks = d['blocks']
            self.final_state , _ = make_final_state(self.initial_state, self.blocks) 
            self.state = self.initial_state   
        except Exception as e:
            print("Error: No state file found")
            raise e
        super().__init__(*args, **kwargs)

    # check if requested data satisfies condition
    def do_GET(self):

        # query state and respond here

        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)

        category_type = params["category_type"][0]
        pubkey = params["pubkey"][0]

        result = False
        for category in self.state["all_category"]:
            if category["data"]["category_type"] == category_type:
                category_elements_child = category["data"]["category_elements_child"]
                exists = check_category_elements_child(pubkey, category_elements_child)
                if exists:
                    result = True
                    break

        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        ret = json.dumps({"result": result})
        self.wfile.write(ret.encode('utf-8'))

    # add block data to memory
    def do_POST(self):

        # update state by applying blocks here
        content_length = int(self.headers['content-length'])
        body = self.rfile.read(content_length).decode('utf-8')
        new_block_json = json.loads(body)
        new_block = new_block_json["block"]

        try:
            final_state, final_hash = make_final_state(self.state, [new_block])
            self.state = final_state
            self.hash = final_hash

            # write state to json file
        except Exception as e:
            pass

        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()

def run_server():
    httpd = HTTPServer(('0.0.0.0', 8000), CustomHTTPRequestHandler)
    print("Server started on")
    httpd.serve_forever()


def main():
    run_server()

main()