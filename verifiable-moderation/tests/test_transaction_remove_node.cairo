%lang starknet
from src.transaction_remove_node import (
    verify_transaction_node_remove,
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
func test_verify_transaction_node_remove{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (category_element: CategoryElement*) = alloc();
    let (child_category_element: CategoryElement*) = alloc();
    assert category_element.n_category_elements_child = 2;
    assert category_element.category_elements_child = child_category_element;
    assert category_element.depth = 0;
    assert category_element.width = 0;
    assert category_element.pubkey = 0;

    let (child_category_element_0_0: CategoryElement*) = alloc();
    let (child_category_element_0_1: CategoryElement*) = alloc();
    assert child_category_element[0].category_elements_child = child_category_element_0_0;
    assert child_category_element[0].n_category_elements_child = 0;
    assert child_category_element[0].pubkey = 1;
    assert child_category_element[0].depth = 0;
    assert child_category_element[0].width = 0;

    assert child_category_element[1].category_elements_child = child_category_element_0_1;
    assert child_category_element[1].n_category_elements_child = 3;
    assert child_category_element[1].pubkey = 2;
    assert child_category_element[1].depth = 0;
    assert child_category_element[1].width = 0;

    let (child_category_element_0_1_0: CategoryElement*) = alloc();
    let (child_category_element_0_1_1: CategoryElement*) = alloc();
    let (child_category_element_0_1_2: CategoryElement*) = alloc();

    assert child_category_element_0_1[0].category_elements_child = child_category_element_0_1_0;
    assert child_category_element_0_1[0].n_category_elements_child = 1;
    assert child_category_element_0_1[0].pubkey = 789;
    assert child_category_element_0_1[0].depth = 0;
    assert child_category_element_0_1[0].width = 0;

    assert child_category_element_0_1[1].category_elements_child = child_category_element_0_1_1;
    assert child_category_element_0_1[1].n_category_elements_child = 1;
    assert child_category_element_0_1[1].pubkey = 123;
    assert child_category_element_0_1[1].depth = 0;
    assert child_category_element_0_1[1].width = 0;

    assert child_category_element_0_1[2].category_elements_child = child_category_element_0_1_2;
    assert child_category_element_0_1[2].n_category_elements_child = 1;
    assert child_category_element_0_1[2].pubkey = 456;
    assert child_category_element_0_1[2].depth = 0;
    assert child_category_element_0_1[2].width = 0;

    let (child_category_element_0_1_0_0: CategoryElement*) = alloc();
    let (child_category_element_0_1_1_0: CategoryElement*) = alloc();
    let (child_category_element_0_1_2_0: CategoryElement*) = alloc();

    assert child_category_element_0_1_0[0].category_elements_child = child_category_element_0_1_0_0;
    assert child_category_element_0_1_0[0].n_category_elements_child = 0;
    assert child_category_element_0_1_0[0].pubkey = 5;
    assert child_category_element_0_1_0[0].depth = 0;
    assert child_category_element_0_1_0[0].width = 0;

    assert child_category_element_0_1_1[0].category_elements_child = child_category_element_0_1_1_0;
    assert child_category_element_0_1_1[0].n_category_elements_child = 0;
    assert child_category_element_0_1_1[0].pubkey = 3;
    assert child_category_element_0_1_1[0].depth = 0;
    assert child_category_element_0_1_1[0].width = 0;

    assert child_category_element_0_1_2[0].category_elements_child = child_category_element_0_1_2_0;
    assert child_category_element_0_1_2[0].n_category_elements_child = 0;
    assert child_category_element_0_1_2[0].pubkey = 4;
    assert child_category_element_0_1_2[0].depth = 0;
    assert child_category_element_0_1_2[0].width = 0;


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

    assert command[0] = COMMAND_NODE_REMOVE;
    assert command[1] = category_id;
    assert command[2] = 123;

    let transaction = Transaction(
        n_command = 3,
        command = command,
        prev_block_hash = 990,
        command_hash = 991,
        msg_hash = 992,
        signature_r = 993, // recover public key from message and signature.
        signature_s = 994,
        pubkey = 0,
    );
    let (new_state: State*) = verify_transaction_node_remove(state, transaction);
    
    assert new_state.all_category.data.n_category_elements_child = 1;
    assert new_state.all_category.data.category_elements_child[0].n_category_elements_child = 2;
    assert new_state.all_category.data.category_elements_child[0].category_elements_child[1].n_category_elements_child = 2;
    assert new_state.all_category.data.category_elements_child[0].category_elements_child[1].category_elements_child[0].pubkey = 789;
    assert new_state.all_category.data.category_elements_child[0].category_elements_child[1].category_elements_child[0].n_category_elements_child = 1;
    assert new_state.all_category.data.category_elements_child[0].category_elements_child[1].category_elements_child[1].pubkey = 456;
    assert new_state.all_category.data.category_elements_child[0].category_elements_child[1].category_elements_child[1].n_category_elements_child = 1;

    return ();
}