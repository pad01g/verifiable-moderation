from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
import sys, json
import os.path
import glob

# https://avocado-system.com/2022/12/05/%E3%80%90python%E3%80%91json%E3%81%AA%E3%81%A9%E3%82%92%E8%BF%94%E3%81%99http%E3%82%B5%E3%83%BC%E3%83%90%E3%83%BC%E4%BD%9C%E6%88%90/

class Handler(BaseHTTPRequestHandler):

    #POST処理
    def do_POST(self):

        #bodyの内容を出力する
        content_len = int(self.headers.get('Content-Length'))
        post_body = self.rfile.read(content_len).decode('utf8')
        print('\r\n【body】\r\n-----\r\n{}\r\n-----\r\n'.format(post_body))
        self.make_data()
    #GET処理
    def do_GET(self):
        self.make_data()

    def make_data(self):

        #リクエスト情報
        print('path = {}'.format(self.path))

        parsed_path = urlparse(self.path)
        print('parsed: path = {}, query = {}'.format(parsed_path.path, parse_qs(parsed_path.query)))

        #ヘッダー情報を出力する
        print('\r\n【headers】\r\n-----\r\n{}-----'.format(self.headers))
        

        if self.path == "/download":
        #zipファイル処理：Zipファイルをダウンロードする
            self.do_zip_service()
        elif self.path == "/error":
            self.do_error_service()
        else:
        #jsonファイル処理：urlに指定するjsonファイルをレスポンスとして返す
            service_names = []
            files = glob.glob('./*.json')
            for file in files:
                basename = os.path.basename(file)
                service_names.append(os.path.splitext(basename)[0])

            foundFlag = 0

            for name in service_names:
                if self.path == ('/' + name):
                    foundFlag = 1
                    self.do_json_service(name)

            if foundFlag == 0:        
                self.do_notfound()
    
    def do_zip_service(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/zip')
        self.end_headers()
        with open("./test.zip", 'rb') as f:
            self.wfile.write(f.read())

    def do_json_service(self, name):
        f = open(name + ".json", encoding="utf-8")
        result_json = json.load(f)
        f.close()

        self.send_response(200)
        self.send_header('Content-type','application/json')
        self.end_headers()
        self.wfile.write(json.dumps(result_json).encode('UTF-8'))

    #指定する資源がない際の処理
    def do_notfound(self):
        f = open("notfound.json", encoding="utf-8")
        result_json = json.load(f)
        f.close()

        self.send_response(404)
        self.send_header('Content-type','application/json')
        self.end_headers()
        self.wfile.write(json.dumps(result_json).encode('UTF-8'))
        
    def do_error_service(self):
        f = open("error.json", encoding="utf-8")
        result_json = json.load(f)
        f.close()

        self.send_response(401)
        self.send_header('Content-type','application/json')
        self.end_headers()
        print(result_json)
        self.wfile.write(json.dumps(result_json).encode('UTF-8'))

PORT = 3000

httpd = HTTPServer(("", PORT), Handler)
httpd.serve_forever()