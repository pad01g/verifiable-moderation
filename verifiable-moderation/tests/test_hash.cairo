%lang starknet
from src.hash import recompute_child_hash
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

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
    assert category_element[0].n_category_elements_child = 0;
    assert category_element[0].depth = 0;
    assert category_element[0].width = 0;
    assert category_element[0].pubkey = 0;
    let (subarray: felt*) = alloc();
    recompute_child_hash{hash_ptr = pedersen_ptr}(category_element, 1, subarray);
    return ();
}
