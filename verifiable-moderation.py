import json
import copy

from starkware.crypto.signature.signature import (
    private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)

from docker.verimod.src.verimod import (generate_key_pair, generate_blocks, make_initial_state, make_final_state)

def main():
    priv_keys, pub_keys, root_priv_key, root_pub_key = generate_key_pair()

    all_blocks = generate_blocks(priv_keys, pub_keys, root_priv_key, root_pub_key)
    blocks = all_blocks[1:]
    initial_block = all_blocks[0]
    initial_state, initial_hash = make_initial_state(initial_block)
    final_state, final_hash = make_final_state(initial_state, blocks)

    input_data = {
        "blocks": blocks,
        "initial_state": initial_state,
        "initial_hash": initial_hash,
        "final_state": final_state,
        "final_hash": final_hash,
    }

    with open('verifiable-moderation/verifiable-moderation-input.json', 'w') as f:
        json.dump(input_data, f, indent=4)
        f.write('\n')

main()
