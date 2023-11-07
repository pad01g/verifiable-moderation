# what is this?

spec of verifiable bbs (nostr) moderation in STARK-compressed format.

# description

 - verifiable-moderation.py
   - python source of the program.
 - src/verifiable-moderation
   - stark source of the program. it uses cairo v0. it should be upgraded to v1.
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

# prepare parameters for cairo v0

```
$ python3 verifiable-moderation.py
```

# compile and run cairo program

```
make run
```

# run cairo tests

- install protostar from https://github.com/software-mansion/protostar . at least v0.14 works.

```
make test
```

# generate and verify proofs

use https://github.com/andrewmilson/sandstorm to generate and verify proofs. you should use `--num-queries=128` option for prover and `--required-security-bits=128` for verifier. Code at hash `cf8af1749624b59316ec6660b6797591bd1553f7` is confirmed to work.

# see also

 - https://martin.kleppmann.com/2021/01/13/decentralised-content-moderation.html
 - https://medium.com/openbazaarproject/verified-moderators-c83ea2f2c7f3

# License

GPLv3