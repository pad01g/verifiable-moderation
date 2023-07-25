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

        config_file = args.config
        d = {}
        with open(config_file) as f:
            d = json.loads(f)
        if "filter_words" in d:
            self.filter_words = d["filter_words"]
        else:
            self.filter_words = []

        if "password" in d:
            self.password = d["password"]
        else:
            self.password = ""


        super().__init__(*args, **kwargs)

    # return list of filtered words, signed with admin private key
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        # sign and return json
        json_str = json.dumps(self.filter_words)
        signature = ""
        pubkey = ""
        self.wfile.write({"pubkey": pubkey, "signature_r": signature, "signature_s": signature, "json_str": json_str})

    # add filtered words. do not check signature etc. it comes from trusted local source.
    # endpoint is protected by password.
    def do_POST(self):
        content_length = int(self.headers['content-length'])
        body = self.rfile.read(content_length).decode('utf-8')
        new_word_json = json.loads(body)
        new_word = new_word_json["word"]
        if not new_word in self.filter_words:
            self.filter_words.append(new_word)
        # check password
        if "password" in new_word_json and new_word_json["password"] == self.password:
            pass
        else:
            self.send_response(400)
            return
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"result": "ok"}')

def run_server():
    httpd = HTTPServer(('0.0.0.0', 8080), CustomHTTPRequestHandler)
    httpd.serve_forever()


def main():
    run_server()

main()