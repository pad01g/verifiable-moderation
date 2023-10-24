from starkware.cairo.common.hash import hash2
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
    category_id_exists,
    CategoryIdExistsResult,
)

func filter_category_internal(new_category_list: Category*, category_list: Category*, n_category_list: felt, category_id: felt, index: felt) -> () {
    alloc_locals;
    local next_pointer: Category*;
    if (index != n_category_list){
        if (category_list.data.category_type == category_id){
            // do not increment target list pointer
            assert next_pointer = new_category_list;
            // also, do not list value
            //
        }else{
            // increment target list pointer
            assert next_pointer = new_category_list + Category.SIZE;
            // assign list value
            assert [new_category_list] = [category_list];
        }
        filter_category_internal(
            next_pointer,
            category_list + Category.SIZE,
            n_category_list,
            category_id,
            index + 1,
        );
    }
    return ();
}

func filter_category(new_category_list: Category*, category_list: Category*, n_category_list: felt, category_id: felt) -> () {
    filter_category_internal(
        new_category_list,
        category_list,
        n_category_list,
        category_id,
        0
    );
    return ();
}

func remove_category(state: State*, category_id: felt) -> (state: State*) {
    alloc_locals;
    let (filtered_category: Category*) = alloc();

    filter_category(filtered_category, state.all_category, state.n_all_category, category_id);
    let (new_state: State*) = alloc();
    assert new_state.n_all_category = state.n_all_category - 1;
    assert new_state.all_category = filtered_category;
    assert new_state.root_pubkey = state.root_pubkey;
    assert new_state.block_hash = state.block_hash;
    return (state = new_state);
}

func verify_transaction_category_remove(state: State*, transaction: Transaction) -> (state: State*) {
    alloc_locals;
    let (new_state: State*) = alloc();

    tempvar category_id = transaction.command[1];
    let (root, exists, result) = check_category_pubkey_authority(state, CATEGORY_CATEGORY, transaction.pubkey);
    // category remove: this pubkey does not have authority over category
    assert exists = 1;

    let res = category_id_exists(state, category_id);
    // it should exist before delete
    %{
        print(f"[verify_transaction_category_remove] category_id: {ids.category_id}")
        print(f"[verify_transaction_category_remove] res.exists: {memory[ids.res.address_ + ids.CategoryIdExistsResult.exists]}")
        print(f"[verify_transaction_category_remove] res.result: {memory[ids.res.address_ + ids.CategoryIdExistsResult.result]}")
    %}
    assert res.exists = 1;

    let (new_state: State*) = remove_category(state, category_id);

    return (state = new_state);
}