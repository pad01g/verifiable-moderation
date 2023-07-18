# what is this?

spec of verifiable bbs (nostr) moderation in STARK-compressed format.

# description

 - verifiable-moderation.py
   - python source of the program.
 - src/verifiable-moderation
   - stark source of the program.
 - docker/verimod
   - independent daemon server program to check authority of specific public key (e.g. for filter-server).
 - docker/admin
   - add/remove authority for verimod key. admin delegates moderation rights to filter-server.
 - docker/noscl
   - nostr client
 - docker/nostr-rs-relay
   - nostr server
 - docker/filter-server
   - nostr contents filter server. noscl can fetch filters if they like. admin can delegate moderation rights to this filter server.

# prepare parameters

```
$ python3 verifiable-moderation.py
```

# run cairo program

```
export name=verifiable-moderation; cairo-compile src/$name/$name.cairo --output $name.json --cairo_path src && cairo-run --program=$name.json --print_output --layout=dynamic  --print_info --trace_file=$name-trace.bin --memory_file=$name-memory.bin  --debug_error  --program_input=$name-input.json
```

# see also

 - https://martin.kleppmann.com/2021/01/13/decentralised-content-moderation.html
 - https://medium.com/openbazaarproject/verified-moderators-c83ea2f2c7f3

# License

GPLv3