%lang starknet
from src.hash import (
    recompute_child_hash,
    recompute_category_hash_by_reference,
    recompute_state_hash,
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
    // assert [subarray] = 0;
    recompute_child_hash{hash_ptr = pedersen_ptr}(category_element, 1, subarray);
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
    %{
        print(f"state_hash: {hex(ids.state_hash)}")
    %}

    return ();
}

