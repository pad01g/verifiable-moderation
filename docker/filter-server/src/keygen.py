from cairolib.crypto.starkware.crypto.signature.signature import (
    private_to_stark_key, sign, verify, FIELD_PRIME)

from cairolib.crypto.starkware.cairo.common.hash_chain import (compute_hash_chain)

import random

root_priv_key = random.randint(0, FIELD_PRIME)
root_pub_key = private_to_stark_key(root_priv_key)

print(f"{hex(root_priv_key)},{hex(root_priv_key)}")