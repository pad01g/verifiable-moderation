# what is this?

spec of verifiable bbs (nostr) moderation in STARK-compressed format.

# description

 - docker/admin
   - add/remove authority for verimod key. admin delegates moderation rights to filter-server.
 - docker/filter-server
   - nostr contents filter server. noscl can fetch filters if they like. admin can delegate moderation rights to this filter server.
 - docker/noscl-reader
   - nostr client
     - fetch data from filter-server
     - check if data is correctly signed
     - check if signature is delegated by trusted admin
     - check if message by nostr-writer can be shown
 - docker/noscl-writer
   - nostr client
     - just submit messages
 - docker/nostr-rs-relay
   - nostr server
 - docker/verimod
   - independent daemon server program to check authority of specific public key (e.g. for filter-server).

# proof-of-concept

Let's launch components by the following command in first terminal.

```
# first terminal
docker compose up
```

Then, open another terminal and run following command. Under the hood, it fetches filter from filter server and verify its integrity by requesting `verimod` server.

```
# second terminal
docker compose exec -it noscl-reader python3 /root/src/run.py
```

Then, open third terminal and run following command. `noscl-writer` just pipes anything into nostr stream.

```
# third terminal
docker compose exec -it noscl-writer bash /root/src/run.sh
```

Finally, type anything and hit Enter on third terminal. The message will be sent to second terminal. If the message contains censored word, it will be replaced and displayed on second terminal.

# see also

 - https://martin.kleppmann.com/2021/01/13/decentralised-content-moderation.html
 - https://medium.com/openbazaarproject/verified-moderators-c83ea2f2c7f3

# License

GPLv3