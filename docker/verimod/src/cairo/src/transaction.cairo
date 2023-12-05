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

