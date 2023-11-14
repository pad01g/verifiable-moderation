from starkware.cairo.common.hash_chain import hash_chain
// maybe different signature?
from starkware.cairo.common.signature import (
    verify_ecdsa_signature,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    SignatureBuiltin,
)
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_fp_and_pc
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

from src.transaction_common import (
    check_category_pubkey_authority,
    search_tree_pubkey_recursive,
    update_state_category
)

from src.transaction_add_node import (
    verify_transaction_node_create,
)
from src.transaction_remove_node import (
    verify_transaction_node_remove,
)
from src.transaction_add_category import (
    verify_transaction_category_create,
)
from src.transaction_remove_category import (
    verify_transaction_category_remove,
)

func verify_tx_with_signature{
    hash_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*
}(state: State*, transaction: Transaction) -> (state: State*) {

    let (hash_chain_input) = alloc();
    assert [hash_chain_input] = 2;
    assert [hash_chain_input+1] = transaction.command_hash;
    assert [hash_chain_input+2] = state.block_hash;
    let (tx_hash) = hash_chain(hash_chain_input);

    tempvar bh = state.block_hash;
    tempvar ch = transaction.command_hash;

    verify_ecdsa_signature(
        message=tx_hash,
        public_key=transaction.pubkey,
        signature_r=transaction.signature_r,
        signature_s=transaction.signature_s,
    );
    return verify_transaction(state, transaction);
}

func verify_transaction{
    hash_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*
}(state: State*, transaction: Transaction) -> (state: State*) {
    if ([transaction.command] == COMMAND_NODE_CREATE) {

        let res = verify_transaction_node_create(state, transaction);
        return res;
    }else{
        if ([transaction.command] == COMMAND_NODE_REMOVE){
            let res = verify_transaction_node_remove(state, transaction);
            return res;
        }else {
            if ([transaction.command] == COMMAND_CATEGORY_CREATE){
                let res = verify_transaction_category_create(state, transaction);
                return res;
            }else{
                if ([transaction.command] == COMMAND_CATEGORY_REMOVE){
                    let res = verify_transaction_category_remove(state, transaction);
                    return res;
                }else{
                    // raise error
                    assert 0 = 1;
                }
            } 
        }
    }
    return (state = state);
}

func verify_transaction_recursive{
    hash_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*
}(state: State*, n_transactions: felt, transactions: Transaction*) -> (state: State*) {
    alloc_locals;
    if (n_transactions == 0){
        return (state = state);
    }else{

        let (new_state: State*) = verify_tx_with_signature(state, transactions[0]);

        local v3 = state.all_category[1].data.category_type;
        local v4 = state.all_category[1].data.n_category_elements_child;
        local v5;
        if (v4 != 0){
            assert v5 = state.all_category[1].data.category_elements_child[0].n_category_elements_child;
        }else{
            assert v5 = 0;
        }

        local v7 = new_state.all_category[1].data.category_type;
        local v8 = new_state.all_category[1].data.n_category_elements_child;
        local v9;
        if (v8 != 0){
            assert v9 = new_state.all_category[1].data.category_elements_child[0].n_category_elements_child;
        }else{
            assert v9 = 0;
        }
        return verify_transaction_recursive(new_state, n_transactions - 1, transactions + Transaction.SIZE);    
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
    // assign_felt_array(command_ptr+1, transaction.n_command, transaction.command);
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
