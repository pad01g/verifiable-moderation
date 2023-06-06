import json

from starkware.crypto.signature.signature import (
    pedersen_hash, private_to_stark_key, sign, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)

COMMAND_CATEGORY_CREATE = 1
COMMAND_CATEGORY_REMOVE = 2
COMMAND_NODE_CREATE = 3
COMMAND_NODE_REMOVE = 4

CATEGORY_BLOCK = FIELD_PRIME - 1 # = -1 in cairo
CATEGORY_CATEGORY = FIELD_PRIME - 2 # = -2 in cairo

def get_block_hash(block):
    root_messages = block["root_message"]
    if len(root_messages):
        root_message = root_messages[0]
        return pedersen_hash(int(root_message["root_pubkey"],16))
    else:
        transactions_merkle_root = block["transactions_merkle_root"]
        timestamp = block["timestamp"]
        return pedersen_hash(int(transactions_merkle_root, 16), timestamp)

def get_command_hash(command):
    # return hash of array
    # https://stackoverflow.com/questions/36620025/pass-array-as-argument-in-python
    # print(command)
    # return pedersen_hash(*command)
    return compute_hash_chain(command)

def get_transactions_hash(transactions):
    transaction_hashes = []
    for transaction in transactions:
        msg_hash = transaction["msg_hash"]
        signature_r = transaction["signature_r"]
        signature_s = transaction["signature_s"]
        numlist = [int(msg_hash, 16), int(signature_r, 16), int(signature_s, 16)]
        transaction_hashes.append(compute_hash_chain(numlist))
    # return pedersen_hash(*transaction_hashes)
    return compute_hash_chain(transaction_hashes)


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
        pub_keys.append(pub_key)

    return (priv_keys, pub_keys, root_priv_key, root_pub_key)

def generate_blocks(priv_keys, pub_keys, root_priv_key, root_pub_key):
    initial_block = {
        "root_message": [{"root_pubkey": hex(root_pub_key)}],
        "signature_r": None,
        "signature_s": None,
    }
    blocks = [initial_block]
    blocks_num = 3 # initial block is included in count
    txs_num = 2
    for i in range(1,blocks_num):
        transactions = []
        for j in range(txs_num):
            commandInt = [COMMAND_NODE_CREATE, CATEGORY_BLOCK, 0, 1, pub_keys[i*txs_num + j]]
            commandHex = [hex(x) for x in commandInt]
            prev_block_hash = get_block_hash(blocks[i-1])
            command_hash = get_command_hash(commandInt)
            msg_hash = pedersen_hash(command_hash, prev_block_hash)
            r, s = sign(
                msg_hash=msg_hash,
                priv_key=root_priv_key
            )

            transactions.append({
                "command": commandHex,
                "prev_block_hash": hex(prev_block_hash),
                "command_hash": hex(command_hash),
                "msg_hash": hex(msg_hash),
                "signature_r": hex(r),
                "signature_s": hex(s),
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
        r, s = sign(
            msg_hash=get_block_hash(block),
            priv_key=root_priv_key
        )
        block["signature_r"] = hex(r)
        block["signature_s"] = hex(s)

        blocks.append(block)

    return blocks

def main():

    priv_keys, pub_keys, root_priv_key, root_pub_key = generate_key_pair()

    blocks = generate_blocks(priv_keys, pub_keys, root_priv_key, root_pub_key)

    input_data = {
        "blocks": blocks,
    }

    with open('verifiable-moderation-input.json', 'w') as f:
        json.dump(input_data, f, indent=4)
        f.write('\n')

main()