import urllib.request
import json

from starkware.crypto.signature.signature import (
    pedersen_hash, private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)
from subprocess import Popen, PIPE


trusted_root_pubkey=""

# get filter from filter-server

url = 'http://filter-server:8080/'
req = urllib.request.Request(url)
r = urllib.request.urlopen(req).read()
cont = json.loads(r.decode('utf-8'))

derived_pubkey = cont["pubkey"]
signature_r = cont["signature_r"]
signature_s = cont["signature_s"]
json_str = cont["json_str"]

filters = json.loads(json_str)

# check if pubkey in json is derived from `trusted_root_pubkey`

url = f'http://verimod:8080/?root_pubkey={trusted_root_pubkey}&derived_pubkey={derived_pubkey}&category=1'
req = urllib.request.Request(url)
r = urllib.request.urlopen(req).read()
verimod_response = json.loads(r.decode('utf-8'))


# check if retrieved filter has correct signature

# pedersen_hash only accepts integer, so we have to convert variable length string into number here.
# just run sha256 of string and take first 254 bits, then hash again by `pedersen_hash`
json_str_sha256 = sha256(json_str)
msg_hash = pedersen_hash(json_str_sha256)
correct_signature = verify(msg_hash, int(signature_r,16), int(signature_s, 16), int(derived_pubkey, 16))

# finally, run `noscl home` and filter contents by filter

kwargs = {
    "stdin": PIPE,
    "stdout": PIPE,
    "universal_newlines": True,  # text mode
    "bufsize": 1,  # line buffered
}

with Popen(["noscl", "home"], **kwargs) as process:
    while True:
        output = process.stdout.readline()
        if output in filters:
            # censor contents
            pass
        else:
            print(output)
