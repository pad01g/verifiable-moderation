# Verimod

## 確認した動作例

Verimodを使用する際の基本的な動作手順は以下の通り。

### コンテナの作成

以下のコマンドを実行し、Verimodのコンテナを作成。この時点では、サーバーは立ち上がっていない。

```sh
docker-compose up -d
```

### シェルへのアクセス

```sh
docker compose exec
verimod /bin/sh
```

### サーバーの立ち上げ

```sh
cd /usr/src/verimod
python3 server.py
```

### POSTリクエストの送信
`block.json`にブロックの情報が入っている状態で以下を実行。
```sh
curl -X POST -H "Content-Type: application/json" -d @block.json http://localhost:8000
```
### GETリクエストの送信
```sh
curl -v "http://localhost:8000/?category_type=0x800000000000010ffffffffffffffffffffffffffffffffffffffffffffffff&pubkey=0x22285e2a1c84a7b6e283eb1ee28a40ba30874aff62617ba1220d7dc6a2b1e70"
```
