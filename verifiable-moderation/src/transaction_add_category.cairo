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
)

func append_category{
    hash_ptr: HashBuiltin*,
}(state: State*, category_id: felt) -> (state: State*) {
    alloc_locals;
    let (hash_chain_input: felt*) = alloc();
    assert [hash_chain_input] = 1;
    assert [hash_chain_input+1] = 0;
    let (category_category_data_hash) = hash_chain(hash_chain_input);
    let (hinput) = alloc();
    assert [hinput] = 2;
    assert [hinput+1] = category_id;
    assert [hinput+2] = category_category_data_hash;
    let (category_hash) = hash_chain(hinput);
    let (category_elements_child: CategoryElement*) = alloc();
    let category = Category(
        hash = category_hash,
        data = CategoryData(
            category_type = category_id,
            n_category_elements_child = 0,
            category_elements_child = category_elements_child,
        ),
    );
    
    let (new_state: State*) = alloc();
    assert new_state.n_all_category = state.n_all_category + 1;
    assert new_state.all_category = state.all_category;
    assert new_state.all_category[state.n_all_category] = category;
    assert new_state.root_pubkey = state.root_pubkey;
    assert new_state.block_hash = state.block_hash;

    return (state = new_state);
}

func verify_transaction_category_create{
    hash_ptr: HashBuiltin*,
}(state: State*, transaction: Transaction) -> (state: State*) {
    alloc_locals;
    let (new_state: State*) = alloc();

    tempvar category_id = transaction.command[1];
    let (root, exists, result) = check_category_pubkey_authority(state, CATEGORY_CATEGORY, transaction.pubkey);
    if (exists == 0) {
        if (root == 0){
            // category create: this pubkey does not have authority over category
            assert 0 = 1;
        } else {
            // root is trying to add new category. that's ok
        }
    }

    let result_dict = category_id_exists(state, category_id);
    // it should not exist
    assert result_dict.exists = 0;

    // finally append category to state here
    let (new_state: State*) = append_category(state, category_id);

    return (state = new_state);
}
