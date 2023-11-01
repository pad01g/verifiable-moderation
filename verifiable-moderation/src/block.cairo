from starkware.cairo.common.hash_chain import hash_chain
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.signature import (
    verify_ecdsa_signature,
)
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

from src.transaction import (
    calc_transactions_merkle_root,
    verify_transaction_recursive,
)

// verify block hash and signature.
func verify_block{hash_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*}(state:State*, block: Block*){
    // check block authenticity except for transaction validity.
    let transactions_merkle_root_recalc = calc_transactions_merkle_root(block.transactions, block.n_transactions);
    assert block.transactions_merkle_root = transactions_merkle_root_recalc;
    let (hash_chain_input) = alloc();
    assert [hash_chain_input] = 2;
    assert [hash_chain_input+1] = transactions_merkle_root_recalc;
    assert [hash_chain_input+2] = block.timestamp;
    let (block_hash) = hash_chain(hash_chain_input);
    verify_ecdsa_signature(
        message=block_hash,
        public_key=block.pubkey,
        signature_r=block.signature_r,
        signature_s=block.signature_s,
    );
    return ();
}

func update_block{hash_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*}(state: State*, block: Block*) -> (state: State*) {
    alloc_locals;
    // check if block itself has correct signature, timestamp and block reference.
    // lookup CATEGORY_BLOCK table and if pubkey is correct.
    verify_block(state, block);
    // check contents of block (txs) are correct.
    let (new_state) = verify_transaction_recursive(state, block.n_transactions,  block.transactions);
    return (state=new_state);
}

func update_block_recursive{hash_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*}(state: State*, n_blocks: felt, blocks: Block*) -> (state: State*) {
    alloc_locals;
    if (n_blocks == 0){
        return (state=state);
    }else{
        let (new_state) = update_block(state, blocks);
        tempvar v1 = state.all_category[0].data.category_type;
        tempvar v2 = state.all_category[0].data.n_category_elements_child;
        tempvar v3 = state.all_category[1].data.category_type;
        tempvar v4 = state.all_category[1].data.n_category_elements_child;
        tempvar v5 = new_state.all_category[0].data.category_type;
        tempvar v6 = new_state.all_category[0].data.n_category_elements_child;
        tempvar v7 = new_state.all_category[1].data.category_type;
        tempvar v8 = new_state.all_category[1].data.n_category_elements_child;
        // tempvar v9 = new_state.all_category[2].data.category_type;
        // tempvar v10 = new_state.all_category[2].data.n_category_elements_child;
        %{
            print(f"[update_block_recursive] state.all_category[0].data.category_type: {hex(ids.v1)}")
            print(f"[update_block_recursive] state.all_category[0].data.n_category_elements_child: {hex(ids.v2)}")
            print(f"[update_block_recursive] state.all_category[1].data.category_type: {hex(ids.v3)}")
            print(f"[update_block_recursive] state.all_category[1].data.n_category_elements_child: {hex(ids.v4)}")
            print(f"[update_block_recursive] new_state.all_category[0].data.category_type: {hex(ids.v5)}")
            print(f"[update_block_recursive] new_state.all_category[0].data.n_category_elements_child: {hex(ids.v6)}")
            print(f"[update_block_recursive] new_state.all_category[1].data.category_type: {hex(ids.v7)}")
            print(f"[update_block_recursive] new_state.all_category[1].data.n_category_elements_child: {hex(ids.v8)}")
            # print(f"[update_block_recursive] new_state.all_category[2].data.category_type: {hex(ids.v9)}")
            # print(f"[update_block_recursive] new_state.all_category[2].data.n_category_elements_child: {hex(ids.v10)}")
        %}
        return update_block_recursive(new_state, n_blocks - 1, blocks + Block.SIZE);    
    }
}
