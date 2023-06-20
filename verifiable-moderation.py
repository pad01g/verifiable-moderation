import json
import copy

from starkware.crypto.signature.signature import (
    pedersen_hash, private_to_stark_key, sign, verify, FIELD_PRIME)

from starkware.cairo.common.hash_chain import (compute_hash_chain)

COMMAND_CATEGORY_CREATE = 1
COMMAND_CATEGORY_REMOVE = 2
COMMAND_NODE_CREATE = 3
COMMAND_NODE_REMOVE = 4

CATEGORY_BLOCK = FIELD_PRIME - 1 # = -1 in cairo
CATEGORY_CATEGORY = FIELD_PRIME - 2 # = -2 in cairo

# we prefer use of string over integer for ease of debugging.
# for example, public keys can be expressed as integers and strings in python,
# but we always use strings if possible.
# function arguments are affected by this policy.

def get_block_hash(block):
    root_messages = block["root_message"]
    if len(root_messages):
        root_message = root_messages[0]
        return pedersen_hash(int(root_message["root_pubkey"],16))
    else:
        transactions_merkle_root = get_transactions_hash(block["transactions"])
        timestamp = block["timestamp"]
        return pedersen_hash(transactions_merkle_root, timestamp)

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
    blocks_num = 4 # initial block is included in count
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

            else: # third block
                # remove nodes and categories
                if j == 0:
                    commandInt = [COMMAND_NODE_REMOVE, CATEGORY_BLOCK, pub_keys[4]]
                elif j == 1:
                    commandInt = [COMMAND_NODE_REMOVE, CATEGORY_BLOCK, pub_keys[3]]
                elif j == 2:
                    commandInt = [COMMAND_NODE_REMOVE, CATEGORY_CATEGORY, pub_keys[5]]
                else:
                    commandInt = [COMMAND_CATEGORY_REMOVE, new_category_id]

            commandHex = [hex(x) for x in commandInt]
            prev_block_hash = get_block_hash(blocks[i-1])
            command_hash = get_command_hash(commandInt)
            msg_hash = pedersen_hash(command_hash, prev_block_hash)
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

            else: # third block
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
        else: # third block
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

    return blocks

def add_node_to_state_by_reference(data, pubkey: str, node) -> bool:
    for child in data["category_elements_child"]:
        if child["pubkey"] == pubkey:
            child["category_elements_child"].append(node)
            return True
        else:
            node_add_result = add_node_to_state_by_reference(child, pubkey, node)
            if node_add_result:
                return True
    return False
            

def apply_command_node_create(state, command: [int], pubkey: str):

    if len(command) != 5:
        raise Exception("invalid argument number for COMMAND_NODE_CREATE")

    category_id = hex(command[1])
    depth = command[2]
    width = command[3]
    node_pubkey = command[4]

    # verify transaction. does it have correct authority in current state?
    pubkey_auth = check_category_pubkey_authority(state, category_id, pubkey)
    new_state = copy.deepcopy(state)
    if not pubkey_auth["exists"] and not pubkey_auth["root"]:
        raise Exception(f"node create: this pubkey {pubkey} does not have authority over category {hex(category_id)}")
    elif not pubkey_auth["exists"] and pubkey_auth["root"] and pubkey_auth["result"] is not None:
        # nobody exists in category, and root is trying to add first node.
        # or maybe category does not exist at all
        index = pubkey_auth["result"]
        child = {
            "category_elements_child": [],
            "depth": depth,
            "width": width,
            "pubkey": hex(node_pubkey),
        }
        # add pubkey to root of category
        new_state["state"]["all_category"][index]["data"]["category_elements_child"].append(child)

    elif not pubkey_auth["exists"] and pubkey_auth["root"] and pubkey_auth["result"] is None:
        # root is trying to add node to non-existent category.
        # even root should first create category by himself.
        raise Exception(f"not implemented, unreachable code")
    elif not pubkey_auth["root"]:
        # category pubkey already exists and non-root pubkey is trying to add node
        # print(json.dumps(new_state))
        child = {
            "category_elements_child": [],
            "depth": depth,
            "width": width,
            "pubkey": hex(node_pubkey),
        }
        # try to add child under pubkey
        index = pubkey_auth["result"]
        node_add_result = add_node_to_state_by_reference(new_state["state"]["all_category"][index]["data"], pubkey, child)
        if not node_add_result:
            raise Exception(f"node could not be added")
    else:
        # category pubkey already exists and root pubkey is trying to add node to category
        # @todo this index may not be correct...?
        index = pubkey_auth["result"]
        # this line also updates new_state because of python object reference
        child = {
            "category_elements_child": [],
            "depth": depth,
            "width": width,
            "pubkey": hex(node_pubkey),
        }
        # add pubkey to root of category
        new_state["state"]["all_category"][index]["data"]["category_elements_child"].append(child)
        # @todo update hash

    return new_state


def remove_node_from_state_by_reference(data, pubkey: str) -> bool:
    for child_index in range(len(data["category_elements_child"])):
        child = data["category_elements_child"][child_index]
        if child["pubkey"] == pubkey:
            # remove child from data["category_elements_child"]
            data["category_elements_child"] = [element for (i, element) in enumerate(data["category_elements_child"]) if i != child_index ]
            return True
        else:
            node_remove_result = remove_node_from_state_by_reference(child, pubkey)
            if node_remove_result:
                return True
    return False
            

def apply_command_node_remove(state, command, pubkey):
    if len(command) != 3:
        raise Exception("invalid argument number for COMMAND_NODE_REMOVE")
    category_id = hex(command[1])
    node_pubkey = hex(command[2])

    # verify transaction. does it have correct authority in current state?
    pubkey_auth = check_category_pubkey_authority(state, category_id, pubkey)
    new_state = copy.deepcopy(state)
    if not pubkey_auth["exists"]:
        raise Exception(f"node remove: this pubkey {pubkey} does not have authority over category {hex(category_id)}")
    elif pubkey_auth["root"]:
        index = pubkey_auth["result"]
        # remove node from category root
        f = lambda node: node["pubkey"] != node_pubkey
        new_state["state"]["all_category"][index]["data"]["category_elements_child"] = list(filter(f, new_state["state"]["all_category"][index]["data"]["category_elements_child"]))
        # @todo update hash
    else:
        # search pubkey from tree object.
        index = pubkey_auth["result"]
        node_remove_result = remove_node_from_state_by_reference(new_state["state"]["all_category"][index]["data"], node_pubkey)
        if not node_remove_result:
            raise Exception(f"node could not be removed")


    return new_state

def apply_command_category_create(state, command, pubkey):

    if len(command) != 2:
        raise Exception("invalid argument number for COMMAND_CATEGORY_CREATE")
    # use hex for category
    category_id_int = command[1]
    category_id_hex = hex(category_id_int)

    # verify transaction. does it have correct authority in current state?
    pubkey_auth = check_category_pubkey_authority(state, hex(CATEGORY_CATEGORY), pubkey)
    if not pubkey_auth["exists"] and not pubkey_auth["root"]:
        raise Exception(f"category create: this pubkey {pubkey} does not have authority over category {hex(CATEGORY_CATEGORY)}")
    elif not pubkey_auth["exists"] and pubkey_auth["root"]:
        # root is trying to add new category. that's ok
        pass

    result_dict = category_id_exists(state, category_id_hex)
    if result_dict["exists"]:
        raise Exception(f"category id {category_id_hex} already exists")

    new_state = copy.deepcopy(state)

    # empty at first
    category_category_data_hash = pedersen_hash(0)
    category_hash = pedersen_hash(category_id_int, category_category_data_hash)

    new_state["state"]["all_category"].append({
        "hash": hex(category_hash), # hash consists of `category_type` and `category_elements_child`
        "data": {
            "category_type": category_id_hex,
            "category_elements_child": [], # this could be another merkle tree
        }
    })
    # @todo update hash

    return new_state

def apply_command_category_remove(state, command: [int], pubkey: str):
    if len(command) != 2:
        raise Exception("invalid argument number for COMMAND_CATEGORY_REMOVE")
    category_id = hex(command[1])

    # verify transaction. does it have correct authority in current state?
    pubkey_auth = check_category_pubkey_authority(state, hex(CATEGORY_CATEGORY), pubkey)
    if not pubkey_auth["exists"]:
        print(json.dumps(state, indent=4))
        raise Exception(f"category remove: this pubkey {pubkey} does not have authority over category {hex(CATEGORY_CATEGORY)}")

    result_dict = category_id_exists(state, category_id)
    if not result_dict["exists"]:
        raise Exception(f"category id {category_id} does not exist")

    new_state = copy.deepcopy(state)

    index = pubkey_auth["result"]
    # remove element from new_state
    f = lambda element: element["data"]["category_type"] != category_id
    new_state["state"]["all_category"] = list(filter(f, new_state["state"]["all_category"]))
    # @todo update hash
    

    return new_state

def apply_transaction_to_state(state, transaction):
    # check if the transaction has correct signature of author.
    signature_r = transaction["signature_r"]
    signature_s = transaction["signature_s"]
    pubkey = transaction["pubkey"]
    command = transaction["command"]
    commandInt = list(map(lambda x: int(x, 16), command))
    prev_block_hash = state["block_hash"]

    command_hash = get_command_hash(commandInt)
    msg_hash = pedersen_hash(command_hash, int(prev_block_hash, 16))
    correct_signature = verify(msg_hash, int(signature_r,16), int(signature_s, 16), int(pubkey, 16))
    if not correct_signature:
        # print(json.dumps(state, indent=4))
        raise Exception("transaction signature is incorrect: " + json.dumps(transaction))

    if len(commandInt) < 2:
        raise Exception("not enough command arguments")

    new_state = copy.deepcopy(state)
    command_type = commandInt[0]
    if command_type == COMMAND_NODE_CREATE:
        new_state = apply_command_node_create(new_state, commandInt, pubkey)
    elif command_type == COMMAND_NODE_REMOVE:
        new_state = apply_command_node_remove(new_state, commandInt, pubkey)
    elif command_type == COMMAND_CATEGORY_CREATE:
        new_state = apply_command_category_create(new_state, commandInt, pubkey)
    elif command_type == COMMAND_CATEGORY_REMOVE:
        new_state = apply_command_category_remove(new_state, commandInt, pubkey)
    else:
        raise Exception("unknown command type: "+ command_type)
    
    # print("apply tx to state", json.dumps(new_state))
    return new_state

def category_id_exists(state, category: str):
    # check if category exists in this state
    # flatten this tree and get all leaves
    exists = False
    result = None
    for i in range(len(state["state"]["all_category"])):
        # print(state["state"]["all_category"][i]["data"]["category_type"], category)
        if state["state"]["all_category"][i]["data"]["category_type"] == category:
            exists = True
            result = i
            break
    return {"exists": exists, "result": result}

# return True or False
def search_tree_pubkey_recursive(tree_data, pubkey: str):
    exists_in_child = [False]
    for category_element in tree_data["category_elements_child"]:
        if category_element["pubkey"] == pubkey:
            return True
        else:
            exists_in_child.append(search_tree_pubkey_recursive(category_element, pubkey))
    return any(exists_in_child)

# this function decides if given `category` has `pubkey` in its leaves.
# you cannot check if you can create currently non-existent `category` using this function.
def check_category_pubkey_authority(state, category: str, pubkey: str):
    result_dict = category_id_exists(state, category)
    exists = result_dict["exists"]
    index = result_dict["result"]

    # if exists:
    #     return {"exists": True, "result": result, "root": False}
    # else:
    #     return {"exists": False, "result": result, "root": False}

    # it is possible that no nodes exist in leaf.
    # in that case, only root can add its first leaves.
    if exists and state["state"]["root_pubkey"] == pubkey and len(state["state"]["all_category"][index]["data"]["category_elements_child"]) == 0:
        return {"exists": exists, "result": index, "root": True}
    elif state["state"]["root_pubkey"] == pubkey:
        # search root hierarchy, root is trying to add node on top level
        return {"exists": exists, "result": index, "root": True}
    elif exists:
        # search whole tree, non-root pubkey is trying to add node on some level
        # check if leaf data has pubkey in it, if leaf has any `category_elements_child`.
        pubkey_child_exists = search_tree_pubkey_recursive(state["state"]["all_category"][index]["data"], pubkey)
        return {"exists": pubkey_child_exists, "result": index, "root": False}

        # raise Exception("not implemented")
    else:
        # it does not have authority
        return {"exists": exists, "result": None, "root": False}



def apply_block_to_state(state, block):
    # also check if the block has correct signature of author.
    block_hash = get_block_hash(block)
    signature_r = block["signature_r"]
    signature_s = block["signature_s"]
    pubkey: str = block["pubkey"]
    correct_signature = verify(block_hash, int(signature_r,16), int(signature_s, 16), int(pubkey, 16))
    if not correct_signature:
        raise Exception("block signature is incorrect: " + hex(block_hash))
    
    # verify block first, does block producer have authority in CATEGORY_BLOCK?
    pubkey_auth = check_category_pubkey_authority(state, hex(CATEGORY_BLOCK), pubkey)
    if not pubkey_auth["exists"] and not pubkey_auth["root"]:
        print(json.dumps(pubkey), json.dumps(pubkey_auth), json.dumps(state))
        raise Exception("public key does not have authority over block creation")
    elif not pubkey_auth["exists"] and pubkey_auth["root"]:
        # this is fine, block was produced by root
        pass
    else:
        # this is also fine, block is verified.
        pass


    # get transaction
    transactions = block["transactions"]
    new_state = copy.deepcopy(state)
    for i in range(len(transactions)):
        new_state = apply_transaction_to_state(new_state, transactions[i])

    new_state["block_hash"] = hex(get_block_hash(block))

    return new_state

# calculate merkle root of first state
def make_initial_state(initial_block):
    # empty at first
    category_block_data_hash = pedersen_hash(0)
    category_block_node = CATEGORY_BLOCK
    category_block_hash = pedersen_hash(category_block_node, category_block_data_hash)

    # empty at first
    category_category_data_hash = pedersen_hash(0)
    category_category_node = CATEGORY_CATEGORY
    category_category_hash = pedersen_hash(category_category_node, category_category_data_hash)

    all_category_hash_int = compute_hash_chain([category_block_hash, category_category_hash])
    all_category_hash_hex = hex(all_category_hash_int)

    root_pubkey = initial_block["root_message"][0]["root_pubkey"]

    all_hash = hex(pedersen_hash(int(root_pubkey,16), all_category_hash_int))

    state = {
        "state": {
            "root_pubkey": root_pubkey,
            "all_category_hash": all_category_hash_hex,
            "all_category": [
                {
                    "hash": hex(category_category_hash), # hash consists of `category_type` and `category_elements_child`
                    "data": {
                        "category_type": hex(category_category_node),
                        "category_elements_child": [], # this could be another merkle tree
                    }
                },
                {
                    "hash": hex(category_block_hash),
                    "data": {
                        "category_type": hex(category_block_node),
                        "category_elements_child": [],
                    }
                }
            ]
        },
        "block_hash": hex(get_block_hash(initial_block))
    }
    return state, all_hash

def recompute_child_hash(elements) -> int:
    if len(elements) == 0:
        return pedersen_hash(0)
    else:
        child_hashes = []
        for element in elements:
            dfs_hash = recompute_child_hash(element["category_elements_child"])
            pubkey_int = int(element["pubkey"],16)
            child_hash = compute_hash_chain([
                dfs_hash,
                element["depth"],
                element["width"],
                pubkey_int,
            ])
            child_hashes.append(child_hash)
        return compute_hash_chain(child_hashes)

# update `hash` in each category (only if marked as `updated`)
def recompute_category_hash_by_reference(category):
    # recursive depth first search to hash everything
    category_type_int = int(category["data"]["category_type"], 16)
    category_data_hash = recompute_child_hash(category["data"]["category_elements_child"])

    category["hash"] = hex(pedersen_hash(category_type_int, category_data_hash))

def recompute_state_hash(state):
    new_state = copy.deepcopy(state)
    # each category hash is recomputed if flagged
    for category in new_state["state"]["all_category"]:
        recompute_category_hash_by_reference(category)
    # now compute updated state hash
    category_hash_list = list(map(lambda category: int(category["hash"], 16), new_state["state"]["all_category"]))
    all_category_hash = compute_hash_chain(category_hash_list)
    new_state["state"]["all_category_hash"] = hex(all_category_hash)
    all_hash = hex(pedersen_hash(int(new_state["state"]["root_pubkey"], 16), all_category_hash))

    return state, all_hash

# calculate merkle root of last state
def make_final_state(initial_state, blocks):
    new_state = copy.deepcopy(initial_state)
    for i in range(len(blocks)):
        # print(i, json.dumps(new_state))
        new_state = apply_block_to_state(new_state, blocks[i])

    new_state, all_hash = recompute_state_hash(new_state)

    return new_state, all_hash

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

    with open('verifiable-moderation-input.json', 'w') as f:
        json.dump(input_data, f, indent=4)
        f.write('\n')

main()