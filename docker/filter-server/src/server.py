from starkware.crypto.signature.signature import (
    pedersen_hash, private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)

import argparse
from http.server import (HTTPServer, BaseHTTPRequestHandler)
import json

def parse_args():
    parser = argparse.ArgumentParser(description='run server with options.')
    parser.add_argument('--config', type=str, default="config.json", help='data location')

    args = parser.parse_args()
    return args

filter_words = []

class CustomHTTPRequestHandler(BaseHTTPRequestHandler):

    def __init__(self, *args, **kwargs):
        global filter_words

        self.args = parse_args()

        config_file = self.args.config
        d = {}
        with open(config_file) as f:
            d = json.load(f)
        if "filter_words" in d:
            filter_words = list(set(filter_words + (d["filter_words"])))
        if "password" in d:
            self.password = d["password"]
        else:
            self.password = ""
        super().__init__(*args, **kwargs)

    def do_GET(self):
        global filter_words
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        json_str = json.dumps(filter_words)
        signature = ""
        pubkey = ""
        ret = json.dumps({"pubkey": pubkey, "signature_r": signature, "signature_s": signature, "json_str": json_str})
        print(ret)
        self.wfile.write(ret.encode())

    def do_POST(self):
        global filter_words
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(b"""
            <html>
            <body>
                <form action="/" method="post">
                    Enter filter words: <input type="text" name="user_input">
                    <input type="submit" value="Submit">
                </form>
            </body>
            </html>
        """)
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        filter_words.append(post_data.decode('utf-8').removeprefix("user_input="))
        print("filter_words:", filter_words)



def run_server():
    httpd = HTTPServer(('0.0.0.0', 8000), CustomHTTPRequestHandler)
    httpd.serve_forever()


def main():
    print("Start server")
    run_server()

main()