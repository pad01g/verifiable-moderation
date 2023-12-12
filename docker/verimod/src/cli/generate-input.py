import json, copy, os, sys

from starkware.crypto.signature.signature import (
    private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)

# Get the current script's directory
current_dir = os.path.dirname(os.path.abspath(__file__))
# Get the parent directory by going one level up
parent_dir = os.path.dirname(current_dir)
# Add the parent directory to sys.path
sys.path.append(parent_dir + "/module")

from verimod.verimod import (
    make_initial_state,
    make_final_state,
    get_block_hash,
    get_command_hash,
    compute_hash_chain_with_length,
    get_transactions_hash,
    COMMAND_CATEGORY_CREATE,
    COMMAND_CATEGORY_REMOVE,
    COMMAND_NODE_CREATE,
    COMMAND_NODE_REMOVE,
    CATEGORY_BLOCK,
    CATEGORY_CATEGORY
)

def generate_key_pair():

    # Generate key pairs.
    priv_keys = []
    pub_keys = []

    root_priv_key = 1234567
    root_pub_key = private_to_stark_key(root_priv_key)

    for i in range(10):
        priv_key = 123456 * i + 654321  # See "Safety note" below.
        priv_keys.append(priv_key)

        pub_key = private_to_stark_key(priv_key)
        # print(f"pub_key {i}: {hex(pub_key)}")
        pub_keys.append(pub_key)

    return (priv_keys, pub_keys, root_priv_key, root_pub_key)

def generate_blocks(priv_keys, pub_keys, root_priv_key, root_pub_key):
    initial_block = {
        "root_message": [{"root_pubkey": hex(root_pub_key)}],
        "signature_r": None,
        "signature_s": None,
    }
    blocks = [initial_block]
    blocks_num = 5 # initial block is included in count
    txs_num = 4
    new_category_id = 1
    for i in range(1,blocks_num):
        transactions = []
        for j in range(txs_num):
            if i == 1: # first block
                if j == 0:
                    # create new category
                    commandInt = [COMMAND_CATEGORY_CREATE, new_category_id]
                elif j == 1:
                    commandInt = [COMMAND_NODE_CREATE, CATEGORY_BLOCK, 2, 3, pub_keys[0]]
                elif j == 2:
                    commandInt = [COMMAND_NODE_CREATE, CATEGORY_CATEGORY, 1, 2, pub_keys[1]]
                else:
                    commandInt = [COMMAND_NODE_CREATE, new_category_id, 1, 2, pub_keys[2]]

            elif i == 2: # second block
                # add nodes under category
                if j == 0:
                    commandInt = [COMMAND_NODE_CREATE, CATEGORY_BLOCK, 1, 2, pub_keys[3]]
                elif j == 1:
                    commandInt = [COMMAND_NODE_CREATE, CATEGORY_BLOCK, 0, 1, pub_keys[4]]
                elif j == 2:
                    commandInt = [COMMAND_NODE_CREATE, CATEGORY_CATEGORY, 0, 1, pub_keys[5]]
                else:
                    commandInt = [COMMAND_NODE_CREATE, new_category_id, 0, 1, pub_keys[6]]

            elif i == 3: # third block
                # remove nodes and categories
                if j == 0:
                    commandInt = [COMMAND_NODE_REMOVE, CATEGORY_BLOCK, pub_keys[4]]
                elif j == 1:
                    commandInt = [COMMAND_NODE_REMOVE, CATEGORY_BLOCK, pub_keys[3]]
                elif j == 2:
                    commandInt = [COMMAND_NODE_REMOVE, CATEGORY_CATEGORY, pub_keys[5]]
                else:
                    commandInt = [COMMAND_CATEGORY_REMOVE, new_category_id]
            else: # fourth block
                if j == 0:
                    # create new category
                    commandInt = [COMMAND_CATEGORY_CREATE, new_category_id]
                elif j == 1:
                    commandInt = [COMMAND_NODE_CREATE, new_category_id, 2, 2, pub_keys[9]]
                elif j == 2:
                    commandInt = [COMMAND_NODE_CREATE, new_category_id, 1, 1, pub_keys[7]]
                else:
                    commandInt = [COMMAND_NODE_CREATE, new_category_id, 1, 1, pub_keys[8]]

            commandHex = [hex(x) for x in commandInt]
            prev_block_hash = get_block_hash(blocks[i-1])
            command_hash = get_command_hash(commandInt)
            msg_hash = compute_hash_chain_with_length([command_hash, prev_block_hash])
            if i == 1: # first block
                priv_key = root_priv_key
                pub_key = root_pub_key

            elif i == 2: # second block
                if j == 0:
                    priv_key = priv_keys[0]
                    pub_key = pub_keys[0]
                elif j == 1:
                    priv_key = priv_keys[3]
                    pub_key = pub_keys[3]
                elif j == 2:
                    priv_key = priv_keys[1]
                    pub_key = pub_keys[1]
                else:
                    priv_key = priv_keys[2]
                    pub_key = pub_keys[2]

            elif i == 3: # third block
                if j == 0:
                    priv_key = priv_keys[3] # remove node 4
                    pub_key = pub_keys[3]
                elif j == 1:
                    priv_key = priv_keys[0] # remove node 3
                    pub_key = pub_keys[0]
                elif j == 2:
                    priv_key = priv_keys[1] # remove node 5
                    pub_key = pub_keys[1]
                else:
                    priv_key = priv_keys[1] # node 1 can remove entire category `new_category_id`
                    pub_key = pub_keys[1]
            else: # fourth block
                if j == 0:
                    priv_key = root_priv_key
                    pub_key = root_pub_key
                elif j == 1:
                    priv_key = root_priv_key
                    pub_key = root_pub_key
                elif j == 2:
                    priv_key = priv_keys[9]
                    pub_key = pub_keys[9]
                else:
                    priv_key = priv_keys[9]
                    pub_key = pub_keys[9]

            r, s = sign(
                msg_hash=msg_hash,
                priv_key=priv_key
            )

            transactions.append({
                "command": commandHex,
                "prev_block_hash": hex(prev_block_hash),
                "command_hash": hex(command_hash),
                "msg_hash": hex(msg_hash),
                "signature_r": hex(r),
                "signature_s": hex(s),
                "pubkey": hex(pub_key),
            })

        transactions_merkle_root = get_transactions_hash(transactions)
        block = {
            "transactions": transactions,
            "transactions_merkle_root": hex(transactions_merkle_root),
            "timestamp": i,
            "root_message": [],
            "signature_r": None,
            "signature_s": None,
        }
        # block signing is done by non-root node after second block
        if i == 1: # first block
            block_priv_key = root_priv_key
            block_pub_key = root_pub_key
        elif i == 2: # second block
            block_priv_key = priv_keys[0]
            block_pub_key = pub_keys[0]
        else: # third block, fourth block
            block_priv_key = priv_keys[0]
            block_pub_key = pub_keys[0]

        r, s = sign(
            msg_hash=get_block_hash(block),
            priv_key=block_priv_key
        )
        block["signature_r"] = hex(r)
        block["signature_s"] = hex(s)
        block["pubkey"] = hex(block_pub_key)

        blocks.append(block)

    # 5th block
    # add last block with root message
    last_block = {
        "transactions": [],
        "transactions_merkle_root": None,
        "timestamp": blocks[-1]["timestamp"] + 1,
        "root_message": [{
            "prev_block_hash": hex(get_block_hash(blocks[-1])),
            "root_pubkey": "0x0",
        }],
        "signature_r": None,
        "signature_s": None,
    }
    r, s = sign(
        msg_hash=get_block_hash(last_block),
        priv_key=root_priv_key
    )
    last_block["signature_r"] = hex(r)
    last_block["signature_s"] = hex(s)
    last_block["pubkey"] = hex(root_pub_key)
    blocks.append(last_block)

    return blocks

def main():
    priv_keys, pub_keys, root_priv_key, root_pub_key = generate_key_pair()

    all_blocks = generate_blocks(priv_keys, pub_keys, root_priv_key, root_pub_key)
    blocks = all_blocks[1:]
    initial_block = all_blocks[0]
    # print(initial_block)
    initial_state, initial_hash = make_initial_state(initial_block)
    # print(initial_state, initial_hash)
    final_state, final_hash = make_final_state(initial_state, blocks)

    input_data = {
        "blocks": blocks,
        "initial_state": initial_state,
        "initial_hash": initial_hash,
        "final_state": final_state,
        "final_hash": final_hash,
    }
    print(json.dumps(input_data, indent=4))

    if len(sys.argv) > 1:
        input_file_path = sys.argv[1]
    else:
        input_file_path = '../cairo/verifiable-moderation-input.json'

    with open(input_file_path, 'w') as f:
        json.dump(input_data, f, indent=4)
        f.write('\n')

main()
