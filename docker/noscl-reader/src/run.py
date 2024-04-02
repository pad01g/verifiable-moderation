import urllib.request
import json, hashlib

from starkware.crypto.signature.signature import (
    private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)
from subprocess import Popen, PIPE
from web3 import Web3
import json

with open("/root/config_contract.json") as f:
    config = json.load(f)
project_id = config["project_id"]
contract_address = config["contract_address"]


infura_http_url = f'https://sepolia.infura.io/v3/{project_id}'
web3 = Web3(Web3.HTTPProvider(infura_http_url))

contract_abi = []

contract = web3.eth.contract(address=contract_address, abi=contract_abi)

try:
    trusted_root_pubkey = contract.call().currentQuestion()
except Exception as e:
    # default value
    trusted_root_pubkey = "0x2f3b7aa96f717634e886860acbae543025c6f534637844b012c2ee467f19477"

# get filter from filter-server

SERVER_URL = 'http://filter-server:8000/'
req = urllib.request.Request(SERVER_URL)
r = urllib.request.urlopen(req).read()
cont = json.loads(r.decode('utf-8'))

derived_pubkey = cont["pubkey"]
# just for debug, assertion is not needed
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
