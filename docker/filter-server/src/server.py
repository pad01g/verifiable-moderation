from starkware.crypto.signature.signature import (
    pedersen_hash, private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)

import argparse
from http.server import (HTTPServer, BaseHTTPRequestHandler)
import json
import hashlib

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
        if "private_key" in d:
            self.pr = d["private_key"]
        super().__init__(*args, **kwargs)
        print("initiated")


    def do_GET(self):
        print("do_GET")
        global filter_words
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        for word in filter_words:
            json_str = json.dumps(word)
            m = hashlib.sha224(json_str.encode())
            print("hash: ", m.hexdigest())
            r, s = sign(msg_hash=int.from_bytes(m.digest(), byteorder='big'), priv_key=int(self.pr, 16))
            ret = json.dumps({"pubkey": private_to_stark_key(int(self.pr, 16)), "signature_r": hex(r), "signature_s": hex(s), "json_str": json_str})
            print(word, ret)
            self.wfile.write(ret.encode())
            print("wrote to file")

    def do_POST(self):
        print("do_POST")
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
        print('content-type: ', self.headers.get('content-type'))
        if self.headers.get('content-type') == 'application/json':
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))
            
            filter_words.append(data["filter_word"])
            filter_words = list(set(filter_words))
        else:
            post_data = self.rfile.read(content_length)
            filter_words.append(post_data.decode('utf-8').removeprefix("user_input="))
            filter_words = list(set(filter_words))
        print("filter_words:", filter_words)

def run_server():
    httpd = HTTPServer(('0.0.0.0', 8000), CustomHTTPRequestHandler)
    httpd.serve_forever()

def main():
    print("Start server")
    run_server()

main()