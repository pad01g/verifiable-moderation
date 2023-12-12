import urllib.request
import json, hashlib

from starkware.crypto.signature.signature import (
    private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)
from subprocess import Popen, PIPE


trusted_root_pubkey=""

# get filter from filter-server

url = 'http://filter-server:8000/'
req = urllib.request.Request(url)
r = urllib.request.urlopen(req).read()
cont = json.loads(r.decode('utf-8'))

derived_pubkey = cont["pubkey"]
assert "0x23592b2754186e35f970c72eea16d46df2570bc68e6ee3069d8aa68d1a1707a" == derived_pubkey
signature_r = cont["signature_r"]
signature_s = cont["signature_s"]
json_str = cont["json_str"]

filters = json.loads(json_str)

# check if pubkey in json is derived from `trusted_root_pubkey`

category_type = "0x1"
url = f'http://verimod:8000/?category_type={category_type}&pubkey={derived_pubkey}&root_pubkey={trusted_root_pubkey}'
req = urllib.request.Request(url)
r = urllib.request.urlopen(req).read()
verimod_response = json.loads(r.decode('utf-8'))
assert verimod_response["result"] == True

# check if retrieved filter has correct signature

# compute_hash_chain only accepts integer, so we have to convert variable length string into number here.
# just run sha256 of string and take first 254 bits, then hash again by `compute_hash_chain`
# json_str_sha256 = sha256(json_str)
msg_hash = hashlib.sha224(json_str.encode())
correct_signature = verify(int.from_bytes(msg_hash.digest(), byteorder='big'), int(signature_r,16), int(signature_s, 16), int(derived_pubkey, 16))

assert correct_signature == True
print(f"filter is verified: {filters}")

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
        for word in filters:
            if word in output:
                # censor contents
                print("[CENSORED]")
            else:
                print(output)
