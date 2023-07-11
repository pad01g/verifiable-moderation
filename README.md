# what is this?

spec of verifiable bbs moderation in STARK-compressed format.

# description

 - verifiable-moderation.py
   - python source of the program.
 - src/verifiable-moderation
   - stark source of the program.
 - src/verimod
   - independent daemon program to check authority of specific public key
 - src/admin
   - check/add/remove authority for verimod public key
 - src/bbsapp
   - example p2p bbs app that uses verimod server. anyone can write to any board, but only moderated messages will be shown.

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