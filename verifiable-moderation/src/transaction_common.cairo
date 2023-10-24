from starkware.cairo.common.hash import hash2
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

func check_category_pubkey_authority(state: State*, category_id: felt, pubkey: felt) -> (root: felt, exists: felt, result: felt) {
    alloc_locals;

    %{
        if True:
            print(f"[check_category_pubkey_authority] ids.state: {ids.state}")
            print(f"[check_category_pubkey_authority] ids.state.address_: {ids.state.address_}")
            print(f"[check_category_pubkey_authority] memory[ids.state.address_]: {memory[ids.state.address_]}")
            print(f"[check_category_pubkey_authority] ids.state.all_category.address_: {ids.state.all_category.address_}")
            # @todo debug here
            print(f"[check_category_pubkey_authority] state.all_category value: {memory[ids.state.all_category.address_]}, state.all_category ref: {ids.state.all_category}")
            category_hash = memory[ids.state.all_category.address_ + ids.Category.SIZE * 0 + ids.Category.hash]
            print(f"[check_category_pubkey_authority] state.all_category hash: {hex(category_hash)}")
            category_data = memory[ids.state.all_category.address_ + ids.Category.SIZE * 0 + ids.Category.data + ids.CategoryData.SIZE * 0 + ids.CategoryData.category_type]
            print(f"[check_category_pubkey_authority] state.all_category data: {hex(category_data)}")
    %}

    let (exists, index) = category_id_exists(state.all_category, state.n_all_category, category_id);

    %{
        if True:
            print(f"exists: {ids.exists}, index: {ids.index}")
            print(f"state.all_category value: {memory[ids.state.all_category.address_]}, state.all_category ref: {ids.state.all_category}")
            category_hash = memory[ids.state.all_category.address_ + ids.Category.SIZE * 0 + ids.Category.hash]
            print(f"state.all_category hash: {hex(category_hash)}")
            category_data = memory[ids.state.all_category.address_ + ids.Category.SIZE * 0 + ids.Category.data + ids.CategoryData.SIZE * 0 + ids.CategoryData.category_type]
            print(f"state.all_category data: {hex(category_data)}")
    %}

    tempvar cat: Category* = state.all_category + index * Category.SIZE;
    %{
        if False:
            print(f"cat: {ids.cat}")
            print(f"cat: {ids.cat.address_}")
            category_hash = memory[ids.cat.address_ + ids.Category.SIZE * 0 + ids.Category.hash]
            print(f"cat hash: {hex(category_hash)}")
            print(f"cat: {ids.cat.data}")
            print(f"cat: {ids.cat.data.address_}")
    %}

    let catdata: CategoryData = cat.data;

    %{
        if False:
            print(f"catdata: {ids.catdata}")
            print(f"catdata addr: {ids.catdata.address_}")
            category_type = memory[ids.catdata.address_ + ids.CategoryData.SIZE * 0 + ids.CategoryData.category_type]
            n_category_elements_child = memory[ids.catdata.address_ + ids.CategoryData.SIZE * 0 + ids.CategoryData.n_category_elements_child]
            print(f"catdata type hex: {hex(category_type)}")
            print(f"catdata n_category_elements_child hex: {hex(n_category_elements_child)}")
    %}

    tempvar n_elements: felt = catdata.n_category_elements_child;
    if (exists != 0 and state.root_pubkey == pubkey and n_elements == 0) {
        return (root = 1, exists = exists, result = index);
    }
    if (state.root_pubkey == pubkey) {
        tempvar root = 1;
        %{
            print("[check_category_pubkey_authority] matching pubkey found for root.")
            print(f"[check_category_pubkey_authority] root: {ids.root}, exists: {ids.exists}, index: {ids.index}")
        %}
        return (root = root, exists = exists, result = index);
    } else {
        if (exists != 0){
            %{
                print("[check_category_pubkey_authority] matching pubkey found for non-root.")
            %}
    
            let (pubkey_child_exists) = search_tree_pubkey_recursive(
                [cast(state.all_category + Category.SIZE * index + Category.data, CategoryData*)],
                pubkey
            );
            return (root = 0, exists = pubkey_child_exists, result = index);
        } else {
            return (root = 0, exists = exists, result = -1);
        }
    }
}

// remaining_count should be internal value
func category_id_exists_internal(category: Category*, n_category: felt, remaining_count: felt, category_id: felt) -> (exists: felt, result: felt) {
    if (remaining_count == 0) {
        return (exists = 0, result = 0);
    }
    %{
        print(f"[category_id_exists] remaining_count: {ids.remaining_count}")
        print(f"[category_id_exists] n_category: {ids.n_category}")
        print(f"[category_id_exists] ids.category.address_: {ids.category.address_}")
        print(f"[category_id_exists] ids.category.address_ + ids.Category.data: {hex(memory[ids.category.address_ + ids.Category.data])}")
        print(f"[category_id_exists] ids.category.address_ + ids.Category.data + ids.CategoryData.category_type: {hex(memory[ids.category.address_ + ids.Category.data + ids.CategoryData.category_type])}")
    %}
    if (category.data.category_type == category_id) {
        return (exists = 1, result = n_category - remaining_count);
    } else {
        return category_id_exists_internal(category + Category.SIZE, n_category, remaining_count - 1, category_id);
    }
}

func category_id_exists(category: Category*, n_category: felt, category_id: felt) -> (exists: felt, result: felt) {
    return category_id_exists_internal(category, n_category, n_category, category_id);
}

// check if element in certain level contains pubkey
func search_tree_pubkey_internal_recursive(element: CategoryElement*, n_element: felt, pubkey: felt) -> (result: felt) {
    if (n_element == 0) {
        return (result = 0);
    } else {
        if (element.pubkey == pubkey) {
            %{
                print(f"[search_tree_pubkey_internal_recursive] matching pubkey found: {hex(ids.pubkey)}")
                print(f"[search_tree_pubkey_internal_recursive] n_element: {hex(ids.n_element)}")
            %}
            return (result = 1);
        }else{
            let (result) = search_tree_pubkey_internal_recursive(element.category_elements_child, element.n_category_elements_child, pubkey);
            if (result != 0) {
                return (result = 1);
            }else{
                return search_tree_pubkey_internal_recursive(element + CategoryElement.SIZE, n_element - 1, pubkey);
            }
        }
    }
}

func search_tree_pubkey_recursive(data: CategoryData, pubkey: felt) -> (result: felt) {
    let (result) = search_tree_pubkey_internal_recursive(data.category_elements_child, data.n_category_elements_child, pubkey);
    return (result = result);
}

func assign_update_state_category_recursive(state: State*, all_category: Category*, category_index: felt, new_category: Category*, current_category_index: felt) -> (state: State*) {
    if (current_category_index == state.n_all_category) {
        return (state = state);
    }

    // let (new_cat_list: Category*) = alloc();
    // assert state.all_category = new_cat_list;

    if (category_index == current_category_index) {
        assert [state.all_category + Category.SIZE * current_category_index] = [new_category];
    } else {
        assert [state.all_category + Category.SIZE * current_category_index] = [all_category + Category.SIZE * current_category_index];
    }
    return assign_update_state_category_recursive(state, all_category, category_index, new_category, current_category_index + 1);
}

// provided category_elements_child, replace specified category elements witth `category_elements_child`
func update_state_category(state: State*, category_index: felt, n_category_elements_child: felt, category_elements_child: CategoryElement*) -> (state: State*) {
    alloc_locals;
    // update category elements in category.
    // add or remove from category elements.
    let (new_state: State*) = alloc();
    assert new_state.block_hash = state.block_hash;
    assert new_state.root_pubkey = state.root_pubkey;
    // number of category does not change. it shold be different method to add/remove category.
    assert new_state.n_all_category = state.n_all_category;

    let (new_cat_list: Category*) = alloc();
    assert new_state.all_category = new_cat_list;

    // get old reference
    tempvar cat: Category* = state.all_category + Category.SIZE * category_index;
    // create new category
    let (new_cat: Category*) = alloc();
    local new_catdata: CategoryData;
    // @todo cast reference, but not sure if it works
    // assert cast(&new_cat + Category.data, CategoryData*) = new_catdata;
    assert new_catdata.category_type = cat.data.category_type;
    // assign new data
    assert new_catdata.n_category_elements_child = n_category_elements_child;
    assert new_catdata.category_elements_child = category_elements_child;
    assert new_cat.data = new_catdata;
    assert new_cat.hash = 0;

    %{
        if True:
            print(f"ids.new_cat: {ids.new_cat}")
            print(f"ids.new_cat.address_: {ids.new_cat.address_}")
            print(f"memory[ids.new_cat.address_]: {memory[ids.new_cat.address_]}")
    %}

    // assign new_cat to `category_index` of new_state.n_all_category, while other categories are copied from `state.all_category`
    let (state_2: State*) = assign_update_state_category_recursive(new_state, state.all_category, category_index, new_cat, 0);
    return (state = state_2);
}