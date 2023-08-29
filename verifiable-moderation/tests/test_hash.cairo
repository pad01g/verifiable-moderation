%lang starknet
from src.hash import recompute_child_hash
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash_chain import hash_chain

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
func test_hash_chain{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;
    let (subarray) = alloc();
    // assert [subarray] = 1;
    // assert [subarray + 1] = 1;
    let (dfs_hash) = hash_chain{hash_ptr = pedersen_ptr}(subarray);
    return ();
}

