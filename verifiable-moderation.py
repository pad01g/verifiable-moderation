import json

from starkware.crypto.signature.signature import (
    pedersen_hash, private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)

COMMAND_CATEGORY_CREATE = 1
COMMAND_CATEGORY_REMOVE = 2
COMMAND_NODE_CREATE = 3
COMMAND_NODE_REMOVE = 4

CATEGORY_BLOCK = FIELD_PRIME - 1 # = -1 in cairo
CATEGORY_CATEGORY = FIELD_PRIME - 2 # = -2 in cairo

MERKLE_TREE_TYPE_LEAF = 1
MERKLE_TREE_TYPE_NODE = 2

def get_block_hash(block):
    root_messages = block["root_message"]
    if len(root_messages):
        root_message = root_messages[0]
        return pedersen_hash(int(root_message["root_pubkey"],16))
    else:
        transactions_merkle_root = get_transactions_hash(block["transactions"])
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
        pubkey = transaction["pubkey"]
        numlist = [int(msg_hash, 16), int(signature_r, 16), int(signature_s, 16), int(pubkey, 16)]
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
                "pubkey": hex(root_pub_key),
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
        block["pubkey"] = hex(root_pub_key)

        blocks.append(block)

    return blocks

def apply_command_node_create(state, command, pubkey):

    if len(command) != 5:
        raise Exception("invalid argument number for COMMAND_NODE_CREATE")

    category_id = command[1]
    depth = command[2]
    width = command[3]
    node_pubkey = command[4]

    # verify transaction. does it have correct authority in current state?
    pubkey_auth = check_category_pubkey_authority(state, category_id, pubkey)
    new_state = state.copy()
    if not pubkey_auth["exists"] and not pubkey_auth["root"]:
        raise Exception(f"this pubkey {pubkey} does not have authority over category {category_id}")
    elif not pubkey_auth["exists"] and pubkey_auth["root"]:
        # root is trying to add first node in this category.
        path = pubkey_auth["result"]["path"]
        # new_state["state"]["all_category_merkle_tree"]["left" or "right"]
        target = new_state["state"]["all_category_merkle_tree"]
        for i in range(path):
            target = target[path[i]]
        # this line also updates new_state because of python object reference
        target["data"]["category_elements_child"] = [{
            "category_elements_child": [],
            "depth": depth,
            "width": width,
            "pubkey": node_pubkey,
        }]

    # elif pubkey_auth.exists:
    else:
        raise Exception(f"not implemented")

    return new_state

def apply_command_node_remove(state, command, pubkey):
    if len(command) != 3:
        raise Exception("invalid argument number for COMMAND_NODE_REMOVE")
    category_id = command[1]
    node_pubkey = command[2]

    # verify transaction. does it have correct authority in current state?
    pubkey_auth = check_category_pubkey_authority(state, category_id, pubkey)
    new_state = state.copy()
    if not pubkey_auth["exists"]:
        raise Exception(f"this pubkey {pubkey} does not have authority over category {category_id}")
    elif pubkey_auth["root"]:
        path = pubkey_auth["result"]["path"]
        target = new_state["state"]["all_category_merkle_tree"]
        for i in range(path):
            target = target[path[i]]
        # remove node from target["data"]["category_elements_child"] too
        # this line also updates new_state because of python object reference
        target["data"]["category_elements_child"] = list(filter(lambda node: node["pubkey"] != node_pubkey, target["data"]["category_elements_child"]))

    else:
        # search pubkey from tree object.
        raise Exception(f"not implemented")


    return new_state

def apply_command_category_create(state, command, pubkey):

    if len(command) != 2:
        raise Exception("invalid argument number for COMMAND_CATEGORY_CREATE")
    category_id = command[1]

    # verify transaction. does it have correct authority in current state?
    pubkey_auth = check_category_pubkey_authority(state, CATEGORY_CATEGORY, pubkey)
    if not pubkey_auth["exists"]:
        raise Exception(f"this pubkey {pubkey} does not have authority over category {CATEGORY_CATEGORY}")

    result_dict = category_id_exists(state, category_id)
    if result_dict["exists"]:
        raise Exception(f"category id {category_id} already exists")

    new_state = state.copy()

    return new_state

def apply_command_category_remove(state, command, pubkey):
    # verify transaction. does it have correct authority in current state?
    pubkey_auth = check_category_pubkey_authority(state, CATEGORY_CATEGORY, pubkey)
    if not pubkey_auth["exists"]:
        raise Exception(f"this pubkey {pubkey} does not have authority over category {CATEGORY_CATEGORY}")

    if len(command) != 2:
        raise Exception("invalid argument number for COMMAND_CATEGORY_REMOVE")
    category_id = command[1]

    return state

def apply_transaction_to_state(state, transaction):
    # check if the transaction has correct signature of author.
    signature_r = transaction["signature_r"]
    signature_s = transaction["signature_s"]
    pubkey = transaction["pubkey"]
    command = transaction["command"]
    commandInt = list(map(lambda x: int(x, 16), command))
    prev_block_hash = state["block_hash"]

    command_hash = get_command_hash(commandInt)
    msg_hash = pedersen_hash(command_hash, prev_block_hash)
    correct_signature = verify(msg_hash, int(signature_r,16), int(signature_s, 16), int(pubkey, 16))
    if not correct_signature:
        raise Exception("transaction signature is incorrect: " + json.dumps(transaction))

    if len(commandInt) < 2:
        raise Exception("not enough command arguments")

    new_state = {}
    command_type = commandInt[0]
    if command_type == COMMAND_NODE_CREATE:
        new_state = apply_command_node_create(state, commandInt, pubkey)
    elif command_type == COMMAND_NODE_REMOVE:
        new_state = apply_command_node_remove(state, commandInt, pubkey)
    elif command_type == COMMAND_CATEGORY_CREATE:
        new_state = apply_command_category_create(state, commandInt, pubkey)
    elif command_type == COMMAND_CATEGORY_REMOVE:
        new_state = apply_command_category_remove(state, commandInt, pubkey)
    else:
        raise Exception("unknown command type: "+ command_type)
    
    return new_state

TREE_PATH_LEFT = 0
TREE_PATH_RIGHT = 1

def flatten_all_leaves_recursive(merkle_tree, path):
    if merkle_tree["type"] == MERKLE_TREE_TYPE_LEAF:
        return [{"leaf": merkle_tree["data"], "path": path}]
    elif merkle_tree["type"] == MERKLE_TREE_TYPE_NODE:
        left = merkle_tree["left"]
        right = merkle_tree["right"]

        left_path = path + [TREE_PATH_LEFT]
        left_leaves = flatten_all_leaves_recursive(left, left_path)
        right_path = path + [TREE_PATH_RIGHT]
        right_leaves = flatten_all_leaves_recursive(right, right_path)

        # join lists
        return left_leaves + right_leaves
    
    # empty leaf or something
    return []

def flatten_all_leaves(merkle_tree):
    return flatten_all_leaves_recursive(merkle_tree, [])

def category_id_exists(state, category):
    # check if category exists in this state
    # flatten this tree and get all leaves
    leaves = flatten_all_leaves(state["state"]["all_category_merkle_tree"])
    exists = False
    result = {}
    for i in range(len(leaves)):
        leaf = leaves[i]["leaf"]
        if leaf["category_type"] == category:
            exists = True
            result = leaves[i]
            break

    return {"exists": exists, "result": result}


# this function decides if given `category` has `pubkey` in its leaves.
# you cannot check if you can create currently non-existent `category` using this function.
def check_category_pubkey_authority(state, category, pubkey):
    result_dict = category_id_exists(state, category_id)
    exists = result_dict["exists"]
    result = result_dict["result"]

    # if exists:
    #     return {"exists": True, "result": result, "root": False}
    # else:
    #     return {"exists": False, "result": result, "root": False}

    # it is possible that no nodes exist in leaf.
    # in that case, only root can add its first leaves.
    if exists and state["state"]["root_pubkey"] == pubkey and result["category_elements_child"] is None:
        return {"exists": exists, "result": result, "root": True}

    # check if leaf data has pubkey in it, if leaf has any `category_elements_child`.
    raise Exception("not implemented")


def apply_block_to_state(state, block):
    # also check if the block has correct signature of author.
    block_hash = get_block_hash(block)
    signature_r = block["signature_r"]
    signature_s = block["signature_s"]
    pubkey = block["pubkey"]
    correct_signature = verify(block_hash, int(signature_r,16), int(signature_s, 16), int(pubkey, 16))
    if not correct_signature:
        raise Exception("block signature is incorrect: " + block_hash)
    
    # verify block first, does block producer has authority in CATEGORY_BLOCK?
    pubkey_auth = check_category_pubkey_authority(state, CATEGORY_BLOCK, pubkey)
    if not pubkey_auth["exists"]:
        raise Exception("public key does not have authority over block creation")

    # get transaction
    transactions = block["transactions"]
    new_state = state
    for i in range(len(transactions)):
        new_state = apply_transaction_to_state(new_state, transactions[i])

    new_state["block_hash"] = get_block_hash(block)

    return new_state

# calculate merkle root of first state
def make_initial_state(initial_block):
    # empty at first
    category_block_merkle_tree_hash = pedersen_hash(0)
    category_block_node = CATEGORY_BLOCK
    category_block_hash = pedersen_hash(category_block_node, category_block_merkle_tree_hash)

    # empty at first
    category_category_merkle_tree_hash = pedersen_hash(0)
    category_category_node = CATEGORY_CATEGORY
    category_category_hash = pedersen_hash(category_category_node, category_category_merkle_tree_hash)

    all_category_merkle_tree_hash = pedersen_hash(category_block_hash, category_category_hash)

    root_pubkey = initial_block["root_message"]["root_pubkey"]

    all_hash = pedersen_hash(root_pubkey, all_category_merkle_tree_hash)

    state = {
        "state": {
            "root_pubkey": root_pubkey,
            "all_category_merkle_tree_hash": all_category_merkle_tree_hash
            "all_category_merkle_tree": { # a merkle tree that consists of category. all categories belong to merkle leaf.
                "type": MERKLE_TREE_TYPE_NODE, # it has child elements
                "left": {
                    "hash": category_category_hash, # hash consists of `category_type` and `category_elements_child`
                    "type": MERKLE_TREE_TYPE_LEAF, # it has no child elements
                    "data": {
                        "category_type": category_category_node,
                        "category_elements_child": None, # this could be another merkle tree
                    }
                },
                "right": {
                    "hash": category_block_hash,
                    "type": MERKLE_TREE_TYPE_LEAF,
                    "data": {
                        "category_type": category_block_node,
                        "category_elements_child": None,
                    }
                }
            }
        },
        "block_hash": hex(get_block_hash(initial_block))
    }
    return state

# calculate merkle root of last state
def make_final_state(initial_state, blocks):
    new_state = initial_state
    for i in range(len(blocks)):
        new_state = apply_block_to_state(new_state, blocks[i])
    return new_state

def main():

    priv_keys, pub_keys, root_priv_key, root_pub_key = generate_key_pair()

    all_blocks = generate_blocks(priv_keys, pub_keys, root_priv_key, root_pub_key)
    blocks = all_blocks[1:]
    initial_block = all_blocks[0]
    initial_state = make_initial_state(initial_block)
    final_state = make_final_state(blocks)

    input_data = {
        "blocks": blocks,
        "initial_state": initial_state,
        "final_state": final_state,
    }

    with open('verifiable-moderation-input.json', 'w') as f:
        json.dump(input_data, f, indent=4)
        f.write('\n')

main()