from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash_chain import hash_chain
from starkware.cairo.common.memcpy import memcpy

from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    SignatureBuiltin,
)
from src.structs import (
    State,
    CategoryElement,
    CategoryData,
    Category,
    Block,
    RootMessage,
    Transaction,
)
from src.consts import (
    COMMAND_CATEGORY_CREATE,
    COMMAND_CATEGORY_REMOVE,
    COMMAND_NODE_CREATE,
    COMMAND_NODE_REMOVE,
    CATEGORY_BLOCK,
    CATEGORY_CATEGORY,    
)

// category_elements: pointer to category elements list.
// n_category_elements: length of category_elements.
// child_hash_list: tracks list of hash of elements scanned so far
func recompute_child_hash{
    hash_ptr: HashBuiltin*,
}(category_elements: CategoryElement*, n_category_elements: felt, child_hash_list: felt*) -> () {
    alloc_locals;

    if (n_category_elements == 0){
        // assert [child_hash_list] = 1;
        // assert [child_hash_list + 1] = 0;
        return ();
    }else{    
        let (subarray) = alloc();
        // memory of subarray is written
        recompute_child_hash(
            category_elements.category_elements_child,
            category_elements.n_category_elements_child,
            subarray
        );
        tempvar n_category_elements_child = category_elements.n_category_elements_child;
        // `subarray` should have elements list. length of subarray is always equal to `n_category_elements_child`
        let (hash_chain_input) = alloc();

        if (category_elements.n_category_elements_child == 0){
            assert [hash_chain_input] = 1;
            assert [hash_chain_input+1] = 0;
        }else{
            assert [hash_chain_input] = n_category_elements_child;
            memcpy(hash_chain_input+1, subarray, category_elements.n_category_elements_child);
        }

        let (dfs_hash) = hash_chain(hash_chain_input);
        // Allocate an array.
        let (ptr) = alloc();

        // Populate values in the array.
        assert [ptr] = 4;
        assert [ptr + 1] = dfs_hash;
        assert [ptr + 2] = category_elements.depth;
        assert [ptr + 3] = category_elements.width;
        assert [ptr + 4] = category_elements.pubkey;

        let (child_hash) = hash_chain(ptr);

        assert [child_hash_list] = child_hash;
        return recompute_child_hash(
            category_elements + CategoryElement.SIZE,
            n_category_elements - 1,
            child_hash_list + 1,
        );
    }
}

func recompute_category_hash_by_reference{
    hash_ptr: HashBuiltin*,
}(category: Category*, n_category: felt, hash_list: felt*) -> () {
    alloc_locals;
    if (n_category == 0){
        return ();
    }else{
        let (subarray) = alloc();
        recompute_child_hash(category.data.category_elements_child, category.data.n_category_elements_child, subarray);
        // subarray must have length

        let (hash_chain_input) = alloc();
        tempvar n_category_elements_child = category.data.n_category_elements_child;
        if (category.data.n_category_elements_child == 0){
            assert [hash_chain_input] = 1;
            assert [hash_chain_input+1] = 0;
        }else{
            assert [hash_chain_input] = category.data.n_category_elements_child;
            memcpy(hash_chain_input+1, subarray, category.data.n_category_elements_child);
        }

        let (category_data_hash) = hash_chain(hash_chain_input);
        let (hinput) = alloc();
        assert [hinput] = 2;
        assert [hinput+1] = category.data.category_type;
        assert [hinput+2] = category_data_hash;
        let (category_hash) = hash_chain(hinput);
        // assert category.hash = category_hash;
        assert [hash_list] = category_hash;
        return recompute_category_hash_by_reference(category + Category.SIZE, n_category - 1, hash_list + 1);
    }
}

func recompute_state_hash{
    hash_ptr: HashBuiltin*,
}(state: State*) -> felt {
    alloc_locals;
    let (category_hash_list) = alloc();
    // get category hash list as felt*.
    recompute_category_hash_by_reference(state.all_category, state.n_all_category, category_hash_list);

    let (hash_chain_input) = alloc();
    if (state.n_all_category == 0){
        assert [hash_chain_input] = 1;
        assert [hash_chain_input+1] = 0;
    }else{
        assert [hash_chain_input] = state.n_all_category;
        memcpy(hash_chain_input+1, category_hash_list, state.n_all_category);
    }
    // need to add root_pubkey, n_all_category, block_hash too

    let (h) = hash_chain(hash_chain_input);

    // compute hash with root_pubkey
    let (hinput) = alloc();
    assert [hinput] = 2;
    assert [hinput+1] = state.root_pubkey;
    assert [hinput+2] = h;

    let (h2) =  hash_chain(hinput);
    return h2;
}

func get_block_hash{
    hash_ptr: HashBuiltin*,
}(block: Block*) -> felt {
    alloc_locals;
    if (block.n_root_message == 0){
        // let (hash_chain_input) = alloc();
        // assert [hash_chain_input] = block.n_transactions;
        // get_transactions_hash(block.n_transactions, block.transactions, hash_chain_input+1);
        // let (h) = hash_chain(hash_chain_input);

        let h = calc_transactions_merkle_root(block.transactions, block.n_transactions);

        local timestamp = block.timestamp;

        let (input) = alloc();
        assert [input] = 2;
        assert [input+1] = h;
        assert [input+2] = timestamp;

        let (h2) = hash_chain(input);
        return h2;
    }else{
        let root_pubkey = block.root_message.root_pubkey;
        if (root_pubkey == 0){
            let (hash_chain_input) = alloc();
            assert [hash_chain_input] = 1;
            assert [hash_chain_input+1] = block.root_message.prev_block_hash;
            let (h) = hash_chain(hash_chain_input);
            return h;
        }else{
            let (hash_chain_input) = alloc();
            assert [hash_chain_input] = 1;
            assert [hash_chain_input+1] = block.root_message.root_pubkey;
            let (h) = hash_chain(hash_chain_input);
            return h;
        }
    }
}

func assign_felt_array(addr: felt*, n_element: felt, element: felt*) -> felt* {
    if (n_element == 0){
        return addr;
    }else{
        assert [addr] = [element];
        return assign_felt_array(addr + 1, n_element - 1, element + 1);
    }
}

func calc_transactions_merkle_root_rec{hash_ptr: HashBuiltin*}(transaction: Transaction*, transaction_hash: felt*, n_transaction: felt) -> felt* {
    alloc_locals;
    // local felt_array: felt*;
    let (felt_array: felt*) = alloc();
    if (n_transaction == 0){
        return (felt_array);
    }
    // verify transaction.msg_hash

    // allocate array for hash chain of command
    let (command_ptr) = alloc();
    assert [command_ptr] = transaction.n_command;
    // assign transaction.command after [command_ptr + 1].
    memcpy(command_ptr+1, transaction.command, transaction.n_command);

    let (command_hash) = hash_chain(command_ptr);
    let (hinput) = alloc();
    assert [hinput] = 2;
    assert [hinput+1] = command_hash;
    assert [hinput+2] = transaction.prev_block_hash;
    let (msg_hash) = hash_chain(hinput);
    assert msg_hash = transaction.msg_hash;

    // Allocate an array.
    let (ptr) = alloc();

    // Populate values in the array.
    assert [ptr] = 4;
    assert [ptr + 1] = transaction.msg_hash;
    assert [ptr + 2] = transaction.signature_r;
    assert [ptr + 3] = transaction.signature_s;
    assert [ptr + 4] = transaction.pubkey;

    let (h) = hash_chain(ptr);
    assert transaction_hash[0] = h;
    return calc_transactions_merkle_root_rec(transaction + Transaction.SIZE, transaction_hash + 1, n_transaction - 1);
}

func calc_transactions_merkle_root{hash_ptr: HashBuiltin*}(transactions: Transaction*, n_transactions: felt) -> felt {
    alloc_locals;
    let (transaction_hashes: felt*) = alloc();
    calc_transactions_merkle_root_rec(transactions, transaction_hashes, n_transactions);

    let (transaction_hashes_ptr) = alloc();
    assert [transaction_hashes_ptr] = n_transactions;
    assign_felt_array(transaction_hashes_ptr+1, n_transactions, transaction_hashes);

    let (h) = hash_chain(transaction_hashes_ptr);
    return h;
}
