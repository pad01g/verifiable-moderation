# key generation

```
python3 keygen.py
```

# config

```
{
    "private_key": "0x172bb1",
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

