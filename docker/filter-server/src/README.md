# key generation

```
python3 keygen.py
```

# config

```
{
    "private_key": "0x261f1e71f64c063745058da3ec2affa0fa8792cdc818e778c34bed06340fb12",
    "filter_words": [],
    "password": "pass1234word"
}
```

# run server

```
python3 server.py --config config.json
```

# get word list

```
curl http://127.0.0.1:8080/
```

# post word

```
curl -d '{"word": "censored-word", "password": "pass1234word"}' -H "content-type: application/json" http://127.0.0.1:8080/
```

