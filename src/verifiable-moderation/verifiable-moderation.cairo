from starkware.cairo.common.hash import hash2
from starkware.cairo.common.hash_chain import hash_chain
// maybe different signature?
from starkware.cairo.common.signature import (
    verify_ecdsa_signature,
)
struct State {
    root_pubkey: felt,
    all_category_hash: felt,
    n_all_category: felt,
    all_category: Category*,
    block_hash: felt,
}

struct Category {
    hash: felt,
    data: CategoryData,
}

struct CategoryData {
    category_type: felt,
    n_category_elements_child: felt,
    category_elements_child: CategoryElement*,
}

struct CategoryElement {
    n_category_elements_child: felt,
    category_elements_child: CategoryElement*,
    depth: felt,
    width: felt,
    pubkey: felt,
}

struct Block {
    n_transactions: felt,
    transactions: Transaction*,
    transactions_merkle_root: felt,
    timestamp: felt,
    n_root_message: felt,
    root_message: RootMessage*, // length could be zero or one
    signature_r: felt, // recover public key from message and signature.
    signature_s: felt,
    pubkey: felt,
}

struct RootMessage {
    prev_block_hash: felt,
    timestamp: felt,
    signature_r: felt,
    signature_s: felt,
}

struct Transaction {
    n_command: felt,
    command: felt*,
    prev_block_hash: felt,
    command_hash: felt,
    msg_hash: felt,
    signature_r: felt, // recover public key from message and signature.
    signature_s: felt,
    pubkey: felt,
}

const COMMAND_CATEGORY_CREATE = 1;
const COMMAND_CATEGORY_REMOVE = 2;
const COMMAND_NODE_CREATE = 3;
const COMMAND_NODE_REMOVE = 4;

const CATEGORY_BLOCK = -1;
const CATEGORY_CATEGORY = -2;

struct Command {
    command_type: felt,
    args: felt*,
}

func category_id_exists(category: Category*, n_category: felt, category_id: felt) -> (exists: felt, result: felt) {
    if (n_category == 0) {
        return (exists = 0, result = 0);
    }
    if (category.category_type == category_id) {
        return (exists = 1, result = 1);
    } else {
        return category_id_exists(category + Category.SIZE, n_category - 1, category_id);
    }
}

// check if element in certain level contains pubkey
func search_tree_pubkey_internal_recursive(element: CategoryElement*, n_element: felt, pubkey: felt) -> (result: felt) {
    if (n_element == 0) {
        return (result = 0);
    } else {
        if (element.pubkey == pubkey) {
            return (result = 1);
        }else{
            %{
                # @todo should be checked upstream
                ids.n_internal_element = len(ids.element.category_elements_child)
            %}
            tempvar (result) = search_tree_pubkey_internal_recursive(element.category_elements_child, n_internal_element, pubkey);
            if (result != 0) {
                return (result = 1);
            }else{
                return search_tree_pubkey_internal_recursive(element + CategoryElement.SIZE, n_element - 1, pubkey);
            }
        }
    }
}

func search_tree_pubkey_recursive(data: CategoryData, pubkey: felt) -> (result: felt) {
    tempvar (result) = search_tree_pubkey_internal_recursive(data.category_elements_child, n_element, pubkey);
    return (result = result);
}

func check_category_pubkey_authority(state: State, category_id: felt, pubkey: felt) -> (root: felt, exists: felt, result: felt) {
    tempvar pubkey_auth: PubkeyAuth;
    tempvar n_category: felt;
    %{
        # @todo should be calculated upstread
        ids.n_category = len(ids.state.all_category)
    %}
    tempvar (exists, index) = category_id_exists(state.all_category, n_category, category_id);

    tempvar n_elements: felt;
    %{
        # @todo should be calculated upstread
        ids.n_elements = len(ids.state.all_category[ids.index].data.category_elements_child)
    %}
    if (exists != 0 && state.root_pubkey == pubkey && n_elements == 0) {
        return (exists = exists, result = index, root = 1);
    } else if (state.root_pubkey == pubkey) {
        return (exists = exists, result = index, root = 1);
    } else if (exists != 0){
        tempvar (pubkey_child_exists) = search_tree_pubkey_recursive(state.all_category[index].data, pubkey);
        return (exists = pubkey_child_exists, result = index, root = 0);
    } else {
        return (exists = exists, result = -1, root = 0);
    }
}

func add_node_to_state_by_reference_recursive(
    n_category_elements_child: felt,
    category_elements_child: CategoryElement*,
    pubkey: felt,
    node: CategoryElement
) -> (result: felt) {
    if (n_category_elements_child == 0){
        return (result = 0);
    }else{
        if (category_elements_child.pubkey == pubkey){
            category_elements_child.category_elements_child[category_elements_child.n_category_elements_child] = node;
            return (result = 1);
        }else{
            tempvar result1 =  add_node_to_state_by_reference_recursive(
                n_category_elements_child - 1,
                category_elements_child + CategoryElement.SIZE,
                pubkey,
                node,
            );
            if (result1 == 1){
                return (result = 1);
            }
            tempvar result2 =  add_node_to_state_by_reference_recursive(
                category_elements_child.n_category_elements_child,
                category_elements_child.category_elements_child,
                pubkey,
                node,
            );
            return (result = result2);
        }
    }
}

func add_node_to_state_by_reference(data: CategoryData, pubkey: felt, node: CategoryElement) -> (result: felt) {
    tempvar (result) = add_node_to_state_by_reference_recursive(
        data.n_category_elements_child,
        data.category_elements_child,
        pubkey,
        node
    );
    return (result = result);
}

func verify_transaction_node_create(state: State, transaction: Transaction) -> (state: State) {
    local new_state: State = state;
    // apply_command_node_create
    tempvar command :felt* = transaction.command;
    tempvar category_id = command[1];
    tempvar depth = command[2];
    tempvar width = command[3];
    tempvar node_pubkey = command[4];
    tempvar pubkey = transaction.pubkey;
    tempvar (exists, result, root) = check_category_pubkey_authority(state, category_id, pubkey);
    if (exists == 0 && root == 0){
        // node create: this pubkey does not have authority over category
        assert 1 == 2;
    } else if (exists == 0 && root == 1 && result != -1) {
        tempvar index = result;
        tempvar child: CategoryElement;
        child.depth = depth;
        child.width = width;
        child.pubkey = node_pubkey;
        // @todo append to existing array
        tempvar n_category_elements_child = new_state.all_category[index].data.n_category_elements_child;
        new_state.all_category[index].data.category_elements_child[n_category_elements_child] = child;
        new_state.all_category[index].data.n_category_elements_child = n_category_elements_child + 1;
    } else if (exists == 0 && root == 1 && result == -1) {
        // even root should first create category by himself.
        assert 1 == 2;
    } else if (root == 0) {
        tempvar index = result;
        tempvar child: CategoryElement;
        child.depth = depth;
        child.width = width;
        child.pubkey = node_pubkey;
        // @todo implement add_node_to_state_by_reference
        tempvar node_add_result = add_node_to_state_by_reference(new_state.state.all_category.[index].data, pubkey, child)
        // verify add result is true
        assert node_add_result == 1;
    } else {
        tempvar index = result;
        tempvar child: CategoryElement;
        child.depth = depth;
        child.width = width;
        child.pubkey = node_pubkey;
        // @todo add by reference
        new_state.all_category[index].data.n_category_elements_child = 1;
        new_state.all_category[index].data.category_elements_child[0] = child;
    }
    return new_state;
}
func verify_transaction_node_remove(state: State, transaction: Transaction) -> (state: State) {
    local new_state: State = state;
    return new_state;
}
func verify_transaction_category_create(state: State, transaction: Transaction) -> (state: State) {
    local new_state: State = state;
    return new_state;
}
func verify_transaction_category_remove(state: State, transaction: Transaction) -> (state: State) {
    local new_state: State = state;
    return new_state;
}

func verify_transaction(state: State, transaction: Transaction) -> (state: State) {
    // verify signature here.
    tempvar pubkey = transaction.pubkey;
    if (transaction.command == COMMAND_NODE_CREATE) {
        return verify_transaction_node_create(state, transaction)
    }else if (transaction.command == COMMAND_NODE_REMOVE){
        return verify_transaction_node_remove(state, transaction)
    }else if (transaction.command == COMMAND_CATEGORY_CREATE){
        return verify_transaction_category_create(state, transaction)
    }else if (transaction.command == COMMAND_CATEGORY_REMOVE){
        return verify_transaction_category_remove(state, transaction)
    }else{
        // raise error
        assert 1 == 2;
    }
    // parse transaction to get command.
    // then parse command get command type and arguments.
    // switch by command type.
    // if COMMAND_CATEGORY_CREATE:
    //    - check that transaction pubkey has authority over target argument by looking up CATEGORY_CATEGORY table.
    //    - check that signature transaction verifies.
    //    - update state according to the command. (add category and re-calculate hashes)
    // if COMMAND_CATEGORY_REMOVE:
    //    - check that transaction pubkey has authority over target argument by looking up CATEGORY_CATEGORY table.
    //    - check that signature transaction verifies.
    //    - update state according to the command. (remove category and re-calculate hashes)
    // if COMMAND_NODE_CREATE:
    //    - check that transaction pubkey has authority over target argument by looking up category_id table.
    //    - check that signature transaction verifies.
    //    - update state according to the command.
    //      - add node in category_id table.
    //      - re-calculate hashes
    // if COMMAND_NODE_REMOVE:
    //    - check that transaction pubkey has authority over target argument by looking up category_id table.
    //    - check that signature transaction verifies.
    //    - update state according to the command.
    //      - mark node in category_id table.
    //      - mark linked child nodes
    //      - remove all marked nodes
    //      - re-calculate hashes
    return new_state;
}

func verify_transaction_recursive(state: State, n_transactions: felt, transactions: Transaction*) -> (state: State) {
    alloc_locals;
    if (n_transactions == 0){
        return state;
    }else{
        local new_state: State = verify_transaction(state, transactions);
        return verify_transaction_recursive(new_state, n_transactions - 1, transactions + Transaction.SIZE);    
    }
}

func calc_transactions_merkle_root_rec(transaction: Transaction*, transaction_hash: felt*, n_transaction: felt) -> felt* {
    if (n_transaction == 0){
        return ();
    }
    // verify transaction.msg_hash
    tempvar command_hash: felt = hash_chain(transaction.command);
    tempvar msg_hash: felt = hash2(command_hash, transaction.prev_block_hash);
    assert msg_hash == transaction.msg_hash;

    const ARRAY_SIZE = 4;

    // Allocate an array.
    let (ptr) = alloc();

    // Populate values in the array.
    assert [ptr] = transaction.msg_hash;
    assert [ptr + 1] = transaction.signature_r;
    assert [ptr + 2] = transaction.signature_s;
    assert [ptr + 3] = transaction.pubkey;

    transaction_hash[0] = hash_chain(ptr);
    return calc_transactions_merkle_root_rec(transaction + Transaction.SIZE, transaction_hash + 1, n_transaction - 1);
}

func calc_transactions_merkle_root(transactions: Transaction*, n_transactions: felt) -> felt {
    tempvar transaction_hashes: felt*;
    calc_transactions_merkle_root_rec(transactions, transaction_hashes, n_transactions);
    return hash_chain(transaction_hashes);
}
// verify block hash and signature.
func verify_block(state:State, block: Block){
    // check block authenticity except for transaction validity.
    tempvar timestamp = block.timestamp;
    tempvar signature_r = block.signature_r;
    tempvar signature_s = block.signature_s;
    tempvar pubkey = block.pubkey;
    tempvar transactions_merkle_root = block.transactions_merkle_root;
    tempvar transactions_merkle_root_recalc = calc_transactions_merkle_root(block.transactions, block.n_transactions);
    assert transactions_merkle_root == transactions_merkle_root_recalc;
    tempvar block_hash = hash2(transactions_merkle_root, timestamp);
    verify_ecdsa_signature(
        message=block_hash,
        public_key=pubkey,
        signature_r=signature_r,
        signature_s=signature_s,
    );
    return ();
}

func update_block(state: State, block: Block) -> (state: State) {
    alloc_locals;
    // check if block itself has correct signature, timestamp and block reference.
    // lookup CATEGORY_BLOCK table and if pubkey is correct.
    verify_block(state, block);
    // check contents of block (txs) are correct.
    local new_state: State = verify_transaction_recursive(state, block.n_transactions,  block.transactions);
    return new_state;
}

func update_block_recursive(state: State, n_blocks: felt, blocks: Block*) -> (state: State) {
    alloc_locals;
    if (n_blocks == 0){
        return state;
    }else{
        local new_state: State = update_block(state, blocks);
        return update_block_recursive(new_state, n_blocks - 1, blocks + Block.SIZE);    
    }
}

func main() {
    alloc_locals;
    // given list of block, update state
    local initial_state: State;
    local initial_hash: felt;
    local n_blocks: felt;
    local blocks: Block*;
    local final_state: State; // latest_state should be hardcoded, also get verified by verifier.
    local final_hash: felt;
    %{
        # assign state variable from input json. it could be initial state.
        # assign blocks variable from input json
        ids.initial_hash = int(program_input["initial_hash"], 16)
        ids.final_hash = int(program_input["final_hash"], 16)
        # blocks
        for block_index in range(len(program_input["blocks"])):
            block = program_input["blocks"][block_index]
            ids.blocks[block_index].transactions_merkle_root = int(block["transactions_merkle_root"], 16)
            ids.blocks[block_index].timestamp = block["timestamp"]
            ids.blocks[block_index].root_message = block["transactions_merkle_root"]["root_message"]
            ids.blocks[block_index].signature_r = int(block["signature_r"], 16)
            ids.blocks[block_index].signature_s = int(block["signature_s"], 16)
            ids.blocks[block_index].pubkey = int(block["pubkey"], 16)
            ids.blocks[block_index].transactions = []
            for tx_index in range(len(block["transactions"])):
                ids.blocks[block_index].n_transactions = len(block["transactions"])
                tx = block["transactions"][tx_index]
                ids.blocks[block_index].transactions[tx_index].prev_block_hash = int(tx["prev_block_hash"], 16)
                ids.blocks[block_index].transactions[tx_index].command_hash = int(tx["command_hash"], 16)
                ids.blocks[block_index].transactions[tx_index].msg_hash = int(tx["msg_hash"], 16)
                ids.blocks[block_index].transactions[tx_index].signature_r = int(tx["signature_r"], 16)
                ids.blocks[block_index].transactions[tx_index].signature_s = int(tx["signature_s"], 16)
                ids.blocks[block_index].transactions[tx_index].pubkey = int(tx["pubkey"], 16)
                ids.blocks[block_index].transactions[tx_index].command = map(lambda el: int(el, 16), tx["command"])
        ids.n_blocks = len(program_input["blocks"])

        def copy_category_elements_by_ref(category_elements, input_category_elements):
            if len(input_category_elements) == 0:
                return
            else:
                for element_index in range(len(input_category_elements)):
                    category_elements[element_index].depth = input_category_elements[element_index]["depth"]
                    category_elements[element_index].width = input_category_elements[element_index]["width"]
                    category_elements[element_index].pubkey = int(input_category_elements[element_index]["pubkey"], 16)
                    copy_category_elements_by_ref(
                        category_elements[element_index].category_elements_child,
                        input_category_elements[element_index]["category_elements_child"]
                    )
        # initial state
        initial_state = program_input["initial_state"]
        ids.initial_state.root_pubkey = int(initial_state["state"]["root_pubkey"], 16)
        ids.initial_state.all_category_hash = int(initial_state["state"]["all_category_hash"], 16)
        ids.initial_state.block_hash = int(initial_state["block_hash"], 16)
        ids.initial_state.all_category = []
        for category_index in range(len(initial_state["state"]["all_category"])):
            ids.initial_state.all_category[category_index].hash = initial_state["state"]["all_category"][category_index]["hash"]
            ids.initial_state.all_category[category_index].data.category_type = int(initial_state["state"]["all_category"][category_index]["data"]["category_type"], 16)
            copy_category_elements_by_ref(
                ids.initial_state.all_category[category_index].data.category_elements_child,
                initial_state["state"]["all_category"][category_index]["data"]["category_elements_child"]
            )

        # final state
        final_state = program_input["final_state"]
        ids.final_state.root_pubkey = int(final_state["state"]["root_pubkey"], 16)
        ids.final_state.all_category_hash = int(final_state["state"]["all_category_hash"], 16)
        ids.final_state.block_hash = int(final_state["block_hash"], 16)
        ids.final_state.all_category = []
        for category_index in range(len(final_state["state"]["all_category"])):
            ids.final_state.all_category[category_index].hash = final_state["state"]["all_category"][category_index]["hash"]
            ids.final_state.all_category[category_index].data.category_type = int(final_state["state"]["all_category"][category_index]["data"]["category_type"], 16)
            copy_category_elements_by_ref(
                ids.final_state.all_category[category_index].data.category_elements_child,
                final_state["state"]["all_category"][category_index]["data"]["category_elements_child"]
            )
    
    %}
    tempvar updated_state = update_block_recursive(initial_state, n_blocks, blocks);
    // assert that updated_state and latest_state match!

    return ();
}
