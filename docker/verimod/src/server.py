from starkware.crypto.signature.signature import (
    pedersen_hash, private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)

import argparse
from http.server import (HTTPServer, BaseHTTPRequestHandler)

def parse_args():
    parser = argparse.ArgumentParser(description='run server with options.')
    parser.add_argument('--config', type=str, default="config.json", help='data location')

    args = parser.parse_args()
    return args

class CustomHTTPRequestHandler(BaseHTTPRequestHandler):

    def __init__(self, *args, **kwargs):
        self.args = parse_args()

        super().__init__(*args, **kwargs)

    # check if requested data satisfies condition
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()

    # add block data to memory
    def do_POST(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()

def run_server():

    httpd = HTTPServer(('0.0.0.0', 8080), CustomHTTPRequestHandler)
    httpd.serve_forever()


def main():
    run_server()

main()