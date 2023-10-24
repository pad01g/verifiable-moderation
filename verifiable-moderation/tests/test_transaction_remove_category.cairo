%lang starknet
from src.transaction_remove_category import (
    verify_transaction_category_remove,
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
func test_verify_transaction_category_remove{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
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

    assert category[0].hash = 1234;
    assert category[0].data = CategoryData(
        category_type = CATEGORY_CATEGORY,
        n_category_elements_child = 1,
        category_elements_child = category_element,
    );

    let (category_element_1: CategoryElement*) = alloc();

    assert category[1].hash = 5678;
    assert category[1].data = CategoryData(
        category_type = 1,
        n_category_elements_child = 0,
        category_elements_child = category_element_1,
    );

    let (state: State*) = alloc();
    assert state.root_pubkey = 1;
    assert state.all_category_hash = 1;
    assert state.n_all_category = 2;
    assert state.all_category = category;
    assert state.block_hash = 1;

    let (command: felt*) = alloc();
    let category_id = 1;

    assert command[0] = COMMAND_CATEGORY_REMOVE;
    assert command[1] = category_id;

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
    let (new_state: State*) = verify_transaction_category_remove(state, transaction);
    
    assert new_state.all_category[0].hash = 1234;
    assert new_state.n_all_category = 1;

    return ();
}