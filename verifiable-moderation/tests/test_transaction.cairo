%lang starknet
from src.transaction import (
    category_id_exists,
    search_tree_pubkey_recursive,
    update_state_category,
    check_category_pubkey_authority,
)
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash_chain import hash_chain
from src.consts import (
    CATEGORY_BLOCK,
    CATEGORY_CATEGORY,    
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

@external
func test_category_id_exists{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (category_element: CategoryElement*) = alloc();
    let (child_category_element: CategoryElement*) = alloc();
    assert category_element.n_category_elements_child = 0;
    assert category_element.category_elements_child = child_category_element;
    assert category_element.depth = 0;
    assert category_element.width = 0;
    assert category_element.pubkey = 0;
    let (subarray: felt*) = alloc();

    let (category: Category*) = alloc();
    let (category_data: CategoryData*) = alloc();
    assert category_data.category_elements_child = category_element;
    assert category_data.n_category_elements_child = 1;
    assert category_data.category_type = CATEGORY_CATEGORY;
    assert category.data = [category_data];

    let (exists_c, result_c) = category_id_exists(category, 1, CATEGORY_CATEGORY);
    let (exists_b, result_b) = category_id_exists(category, 1, CATEGORY_BLOCK);
    assert exists_c = 1;
    assert result_c = 0;
    assert exists_b = 0;
    // should not exist
    assert result_b = 0;

    return ();
}


@external
func test_search_tree_pubkey_recursive{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (category_element: CategoryElement*) = alloc();
    let (child_category_element: CategoryElement*) = alloc();
    assert category_element.n_category_elements_child = 0;
    assert category_element.category_elements_child = child_category_element;
    assert category_element.depth = 0;
    assert category_element.width = 0;
    assert category_element.pubkey = 0;
    let (subarray: felt*) = alloc();

    let (category: Category*) = alloc();
    let (category_data: CategoryData*) = alloc();
    assert category_data.category_elements_child = category_element;
    assert category_data.n_category_elements_child = 1;
    assert category_data.category_type = CATEGORY_CATEGORY;

    let (result_exists) = search_tree_pubkey_recursive([category_data], 0);
    let (result_not_exists) = search_tree_pubkey_recursive([category_data], 1);

    assert result_exists = 1;
    assert result_not_exists = 0;
    return ();
}

@external
func test_update_state_category{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (category_element: CategoryElement*) = alloc();
    let (child_category_element: CategoryElement*) = alloc();
    assert category_element.n_category_elements_child = 0;
    assert category_element.category_elements_child = child_category_element;
    assert category_element.depth = 0;
    assert category_element.width = 0;
    assert category_element.pubkey = 0;

    let (category: Category*) = alloc();
    let (category_data: CategoryData*) = alloc();
    assert category_data.category_elements_child = category_element;
    assert category_data.n_category_elements_child = 1;
    assert category_data.category_type = CATEGORY_CATEGORY;
    assert category.data = [category_data];

    let (state: State*) = alloc();
    assert state.root_pubkey = 1;
    assert state.all_category_hash = 1;
    assert state.n_all_category = 1;
    assert state.all_category = category;
    assert state.block_hash = 1;

    let category_index = 0;
    let n_category_elements_child = 1;

    let (new_category_element: CategoryElement*) = alloc();
    let (new_child_category_element: CategoryElement*) = alloc();
    assert new_category_element.n_category_elements_child = 0;
    assert new_category_element.category_elements_child = new_child_category_element;
    assert new_category_element.depth = 0;
    assert new_category_element.width = 0;
    assert new_category_element.pubkey = 1;

    // state should have category with pubkey = 0
    assert state.all_category.data.category_elements_child.pubkey = 0;

    let (new_state: State*) = update_state_category(state, category_index, n_category_elements_child, new_category_element);

    // now new state should have category with pubkey = 1
    assert new_state.all_category.data.category_elements_child.pubkey = 1;

    return ();
}

@external
func test_check_category_pubkey_authority{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (category_element: CategoryElement*) = alloc();
    let (child_category_element: CategoryElement*) = alloc();
    assert category_element.n_category_elements_child = 0;
    assert category_element.category_elements_child = child_category_element;
    assert category_element.depth = 0;
    assert category_element.width = 0;
    assert category_element.pubkey = 0;

    let (category: Category*) = alloc();
    let (category_data: CategoryData*) = alloc();
    assert category_data.category_elements_child = category_element;
    assert category_data.n_category_elements_child = 1;
    assert category_data.category_type = CATEGORY_CATEGORY;
    assert category.data = [category_data];
    assert category.hash = 1234;

    let (state: State*) = alloc();
    assert state.root_pubkey = 1;
    assert state.all_category_hash = 1;
    assert state.n_all_category = 1;
    assert state.all_category = category;
    assert state.block_hash = 1;

    %{
        print(f"ids.state.all_category.address_: {ids.state.all_category.address_}")
        print(f"ids.state.all_category.address_: {memory[ids.state.all_category.address_]}")
    %}


    // this should exist
    let (root_0, exists_0, result_0) = check_category_pubkey_authority(state, CATEGORY_CATEGORY, 0);

    assert root_0 = 0;
    assert exists_0 = 1;
    assert result_0 = 0;

    // these should not exist
    let (root_1, exists_1, result_1) = check_category_pubkey_authority(state, CATEGORY_CATEGORY, 1);
    let (root_block_0, exists_block_0, result_block_0) = check_category_pubkey_authority(state, CATEGORY_CATEGORY, 1);
    let (root_block_1, exists_block_1, result_block_1) = check_category_pubkey_authority(state, CATEGORY_CATEGORY, 1);

    assert root_1 = 0;
    assert exists_1 = 1;
    assert result_1 = 0;

    return ();
}
