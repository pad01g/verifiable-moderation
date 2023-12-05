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

# see also

 - https://martin.kleppmann.com/2021/01/13/decentralised-content-moderation.html
 - https://medium.com/openbazaarproject/verified-moderators-c83ea2f2c7f3

# License

GPLv3