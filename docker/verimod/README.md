# Verimod

## 確認した動作例

Verimodを使用する際の基本的な動作手順は以下の通り。

### コンテナの作成

以下のコマンドを実行し、Verimodのコンテナを作成。

```sh
docker build -t verimod . 
```

### 本番

#### コンテナ+サーバーの実行
```sh
docker run  --rm --name verimod -p 8000:8000 -v ./src:/usr/src/verimod  verimod
```

### 開発

#### コンテナの実行
```sh
docker run  --rm --name verimod -p 8000:8000 -v ./src:/usr/src/verimod  verimod bash -c "while true; do sleep 5; done"
# この時点では、サーバーは立ち上がっていない。
```

#### シェルへのアクセス
```sh
docker exec -it verimod bash
```

#### サーバーの立ち上げ
```sh
cd /usr/src/verimod
python3 ./server/manage.py migrate
python3 ./server/manage.py runserver 0.0.0.0:8000
```

### POSTリクエストの送信
`block.good.json`などにブロックの情報が入っている状態で以下を実行。
```sh
# successful
docker exec -it verimod curl -X POST -H "Content-Type: application/json" -d @/app/server/block.good.json http://localhost:8000 

# fail
docker exec -it verimod curl -X POST -H "Content-Type: application/json" -d @/app/server/block.bad.json http://localhost:8000 
```

### GETリクエストの送信
```sh
# successful
curl -v "http://localhost:8000/?category_type=0x800000000000010ffffffffffffffffffffffffffffffffffffffffffffffff&pubkey=0x22285e2a1c84a7b6e283eb1ee28a40ba30874aff62617ba1220d7dc6a2b1e70"

# fail (wrong public key)
curl -v "http://localhost:8000/?category_type=0x800000000000010ffffffffffffffffffffffffffffffffffffffffffffffff&pubkey=0x22285e2a1c84a7b6e283eb1ee28a40ba30874aff62617ba1220d7dc6a2b1e71"
```

## ディレクトリ構造
- `src/server/manage.py`:` サーバーの立ち上げを行うファイル。このスクリプトを実行することでDjangoサーバーを立ち上げる。
- `src/server/server`: Djangoサーバーの設定ディレクトリ。ロジェクトの設定（settings.py）、URLルーティング（urls.py）、WSGI設定（wsgi.py）など。
- `src/server/myapp`: サーバーのアプリケーションディレクトリ。ビュー（views.py）など。