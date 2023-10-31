%lang starknet
from src.transaction_common import (
    category_id_exists,
    search_tree_pubkey_recursive,
    update_state_category,
    check_category_pubkey_authority,
)
from src.transaction_add_node import (
    verify_transaction_node_create,
    add_node_to_state_by_reference,
)
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash_chain import hash_chain
from src.consts import (
    CATEGORY_BLOCK,
    CATEGORY_CATEGORY,
    COMMAND_CATEGORY_CREATE,
    COMMAND_CATEGORY_REMOVE,
    COMMAND_NODE_CREATE,
    COMMAND_NODE_REMOVE,
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

    let (state: State*) = alloc();
    assert state.n_all_category = 1;
    assert state.all_category = category;
    assert state.root_pubkey = 123;
    assert state.block_hash = 456;

    let res1 = category_id_exists(state, CATEGORY_CATEGORY);
    let exists_c = res1.exists;
    let result_c = res1.result;
    let res2 = category_id_exists(state, CATEGORY_BLOCK);
    let exists_b = res2.exists;
    let result_b = res2.result;
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

    // this should exist
    let (root_0, exists_0, result_0) = check_category_pubkey_authority(state, CATEGORY_CATEGORY, 0);

    assert root_0 = 0;
    assert exists_0 = 1;
    assert result_0 = 0;

    // root should be one
    let (root_1, exists_1, result_1) = check_category_pubkey_authority(state, CATEGORY_CATEGORY, 1);
    assert root_1 = 1;
    assert exists_1 = 1;
    assert result_1 = 0;

    let (root_block_0, exists_block_0, result_block_0) = check_category_pubkey_authority(state, CATEGORY_BLOCK, 0);
    assert root_block_0 = 0;
    assert exists_block_0 = 0;
    assert result_block_0 = -1; // undefined

    // usually CATEGORY_BLOCK exists but in this state only CATEGORY_CATEGORY exists.
    // so the key is root but category does not exist.
    // also, result (index) will be undefined.
    let (root_block_1, exists_block_1, result_block_1) = check_category_pubkey_authority(state, CATEGORY_BLOCK, 1);
    assert root_block_1 = 1;
    assert exists_block_1 = 0;

    return ();
}

@external
func test_add_node_to_state_by_reference{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
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

    let (new_category_data: CategoryData*) = alloc();
    let (new_category_element: CategoryElement*) = alloc();
    let (new_child_category_element: CategoryElement*) = alloc();
    assert new_category_element.n_category_elements_child = 0;
    assert new_category_element.category_elements_child = new_child_category_element;
    assert new_category_element.depth = 0;
    assert new_category_element.width = 0;
    assert new_category_element.pubkey = 1;
    let (child: CategoryElement*) = alloc();
    assert new_category_data.category_elements_child = child;


    add_node_to_state_by_reference(new_category_data, category_data, 0, new_category_element);

    assert new_category_data.category_elements_child.pubkey = 0;
    assert new_category_data.category_elements_child.category_elements_child.pubkey = 1;

    return ();
}

@external
func test_verify_transaction_node_create{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
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

    let (command: felt*) = alloc();
    let category_id = CATEGORY_CATEGORY;
    let depth = 0;
    let width = 0;
    let node_pubkey = 995;

    assert command[0] = COMMAND_NODE_CREATE;
    assert command[1] = category_id;
    assert command[2] = depth;
    assert command[3] = width;
    assert command[4] = node_pubkey;

    let transaction = Transaction(
        n_command = COMMAND_NODE_CREATE,
        command = command,
        prev_block_hash = 990,
        command_hash = 991,
        msg_hash = 992,
        signature_r = 993, // recover public key from message and signature.
        signature_s = 994,
        pubkey = 0,
    );
    let (new_state: State*) = verify_transaction_node_create(state, transaction);
    
    assert new_state.all_category.data.category_elements_child.pubkey = 0;
    assert new_state.all_category.data.category_elements_child.category_elements_child.pubkey = 995;

    return ();
}