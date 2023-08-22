from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.hash_chain import hash_chain

from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    SignatureBuiltin,
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
from src.consts import (
    COMMAND_CATEGORY_CREATE,
    COMMAND_CATEGORY_REMOVE,
    COMMAND_NODE_CREATE,
    COMMAND_NODE_REMOVE,
    CATEGORY_BLOCK,
    CATEGORY_CATEGORY,    
)

func recompute_child_hash{
    hash_ptr: HashBuiltin*,
}(category_elements: CategoryElement*, n_category_elements: felt, child_hash_list: felt*) -> () {
    alloc_locals;
    if (n_category_elements == 0){
        return ();
    }else{
        let (subarray) = alloc();
        recompute_child_hash(
            category_elements[0].category_elements_child,
            category_elements[0].n_category_elements_child,
            subarray
        );
        // `subarray` should have elements list.
        let (dfs_hash) = hash_chain(subarray);
        
        // Allocate an array.
        let (ptr) = alloc();

        // Populate values in the array.
        assert [ptr] = dfs_hash;
        assert [ptr + 1] = category_elements[0].depth;
        assert [ptr + 2] = category_elements[0].width;
        assert [ptr + 3] = category_elements[0].pubkey;

        let (child_hash) = hash_chain(ptr);
        assert child_hash_list[0] = child_hash;
        return recompute_child_hash(
            category_elements + CategoryElement.SIZE,
            n_category_elements - 1,
            child_hash_list + 1,
        );
    }
}

func recompute_category_hash_by_reference{
    hash_ptr: HashBuiltin*,
}(category: Category*, n_category: felt) -> () {
    alloc_locals;
    if (n_category == 0){
        return ();
    }else{
        let (subarray) = alloc();
        recompute_child_hash(category.data.category_elements_child, category.data.n_category_elements_child, subarray);
        let (category_data_hash) = hash_chain(subarray);
        let (category_hash) = hash2(category.data.category_type, category_data_hash);
        assert category.hash = category_hash;
        return recompute_category_hash_by_reference(category + Category.SIZE, n_category - 1);
    }
}

func recompute_category_hash_recursive{
    hash_ptr: HashBuiltin*,
}(state: State*) -> (state: State*) {
    return (state = state);
}

func get_category_hash_list{
    hash_ptr: HashBuiltin*,
}(category: Category*, n_category_hash_list: felt, category_hash_list: felt*) -> () {
    // recursively assign category hash into category hash list arg, it is just map() function.
    if (n_category_hash_list == 0){
        return ();
    }
    assert category_hash_list[0] = category.hash;
    return get_category_hash_list(category + Category.SIZE, n_category_hash_list - 1, category_hash_list);
}

func recompute_state_hash{
    hash_ptr: HashBuiltin*,
}(state: State*) -> felt {
    alloc_locals;
    let (category_hash_list) = alloc();
    // run recompute_category_hash_recursive
    let (new_state) = recompute_category_hash_recursive(state);
    // get category hash list as felt*.
    get_category_hash_list(new_state.all_category, new_state.n_all_category, category_hash_list);
    let (h) = hash_chain(category_hash_list);
    return h;
}
