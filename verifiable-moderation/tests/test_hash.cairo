%lang starknet
from src.hash import (
    recompute_child_hash,
    recompute_category_hash_by_reference,
    recompute_state_hash,
)
from starkware.cairo.common.hash import hash2
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
from starkware.cairo.common.memcpy import memcpy

@external
func test_hash_chain{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    // Allocate an array.
    let (ptr) = alloc();

    // Populate values in the array.
    assert [ptr] = 4;
    assert [ptr + 1] = 0;
    assert [ptr + 2] = 1;
    assert [ptr + 3] = 2;
    assert [ptr + 4] = 3;

    let (child_hash) = hash_chain{hash_ptr = pedersen_ptr}(ptr);
    local h;
    %{
        # use hex for convinience
        ids.h = int(0x601e94b9063887ec3311c3f85951215d067b6c46cf427be78beb69b369a5fd3)
    %}
    assert child_hash = h;

    let (ptr1) = alloc();
    assert [ptr1] = 2;
    assert [ptr1 + 1] = 0;
    assert [ptr1 + 2] = 1;
    let (hash_1) = hash_chain{hash_ptr = pedersen_ptr}(ptr1);
    let (hash_2) = hash2{hash_ptr = pedersen_ptr}(0, 1);

    // assert hash_1 != hash_2;

    return ();
}

@external
func test_recompute_child_hash{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;
    let (category_element: CategoryElement*) = alloc();
    let (child_category_element: CategoryElement*) = alloc();
    assert category_element.n_category_elements_child = 0;
    assert category_element.category_elements_child = child_category_element;
    assert category_element.depth = 0;
    assert category_element.width = 0;
    assert category_element.pubkey = 0;
    let (subarray: felt*) = alloc();

    let n_category_elements_child = 1;

    recompute_child_hash{hash_ptr = pedersen_ptr}(category_element, n_category_elements_child, subarray);

    %{
        print("subarray[0]: ", hex(memory[ids.subarray]))    
        #print("subarray[1]: ", hex(memory[ids.subarray+1]))    
    %}

    let (hash_chain_input) = alloc();
    assert [hash_chain_input] = n_category_elements_child;

    %{
        print("hash_chain_input[0]: ", hex(memory[ids.hash_chain_input]))    
    %}

    memcpy(hash_chain_input+1, subarray, n_category_elements_child);
    let (dfs_hash) = hash_chain{hash_ptr = pedersen_ptr}(hash_chain_input);

    local h;
    %{
        # use hex for convinience
        ids.h = int(0x7432f3281ff4bb79d201ad49ed90ed1feaad9032e65e83722b2ce978c481e8f)
    %}
    assert dfs_hash = h;
    return ();
}


@external
func test_recompute_category_hash_by_reference{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
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
    local category_hash;

    %{
        # use hex for convinience
        ids.category_hash = int(0x431364ed1f517fbacea1491a38376852e05933f3b0f2786e1ca702f08a82c9d)
    %}
    // assert category.hash = 1896201719796867766069081279408667678411829994352791949344158225950338198685;
    let n_category = 1;
    let (category_hash_list) = alloc();
    recompute_category_hash_by_reference{hash_ptr = pedersen_ptr}(
        category,
        n_category,
        category_hash_list
    );

    // let (hash_chain_input) = alloc();
    // assert [hash_chain_input] = 1;
    // memcpy(hash_chain_input+1, category_hash_list, 1);
    // let (hash) = hash_chain{hash_ptr = pedersen_ptr}(hash_chain_input);
    local h;
    %{
        ids.h = int(0x3f6c71c281f00f1bd4b9fce19dd54e2e4f301c78fd4da7831ccbd261526ac30)
    %}
    assert h = category_hash_list[0];

    return ();
}



@external
func test_recompute_state_hash{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
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
    assert state.root_pubkey = 1;
    assert state.all_category_hash = 1;
    assert state.n_all_category = 1;
    assert state.all_category = category;
    assert state.block_hash = 1;

    // local state_hash;
    let state_hash = recompute_state_hash{hash_ptr = pedersen_ptr}(
        state
    );
    local h;
    %{
        print(f"state_hash: {hex(ids.state_hash)}")
        ids.h = 0x7acc582d0b522d11f37066fad1ed8fbe21dbba2f11653a33813484ce3c7c729;
    %}
    assert state_hash = h;
    return ();
}

