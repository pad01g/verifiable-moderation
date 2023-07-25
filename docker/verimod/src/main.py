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

    # return list of filtered words, signed with admin private key
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()

    # add filtered words. do not check signature etc. it comes from trusted local source.
    # endpoint is protected by password.
    def do_POST(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()

def run_server(args):

    httpd = HTTPServer(('0.0.0.0', 8080), BaseHTTPRequestHandler)
    httpd.serve_forever()


def main():
    args = parse_args()
    run_server(args)

main()