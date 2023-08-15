%builtins pedersen ecdsa

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

struct State {
    root_pubkey: felt,
    all_category_hash: felt,
    n_all_category: felt,
    all_category: Category*,
    block_hash: felt,
}

struct CategoryElement {
    n_category_elements_child: felt,
    category_elements_child: CategoryElement*,
    depth: felt,
    width: felt,
    pubkey: felt,
}

struct CategoryData {
    category_type: felt,
    n_category_elements_child: felt,
    category_elements_child: CategoryElement*,
}

struct Category {
    hash: felt,
    data: CategoryData,
}


struct Block {
    n_transactions: felt,
    transactions: Transaction*,
    transactions_merkle_root: felt,
    timestamp: felt,
    n_root_message: felt,
    root_message: RootMessage*, // length could be zero or one
    signature_r: felt, // recover public key from message and signature.
    signature_s: felt,
    pubkey: felt,
}

struct RootMessage {
    prev_block_hash: felt,
    timestamp: felt,
    signature_r: felt,
    signature_s: felt,
}

struct Transaction {
    n_command: felt,
    command: felt*,
    prev_block_hash: felt,
    command_hash: felt,
    msg_hash: felt,
    signature_r: felt, // recover public key from message and signature.
    signature_s: felt,
    pubkey: felt,
}

const COMMAND_CATEGORY_CREATE = 1;
const COMMAND_CATEGORY_REMOVE = 2;
const COMMAND_NODE_CREATE = 3;
const COMMAND_NODE_REMOVE = 4;

const CATEGORY_BLOCK = -1;
const CATEGORY_CATEGORY = -2;

struct Command {
    command_type: felt,
    args: felt*,
}

func category_id_exists(category: Category*, n_category: felt, category_id: felt) -> (exists: felt, result: felt) {
    if (n_category == 0) {
        return (exists = 0, result = 0);
    }
    %{
        print(f"[category_id_exists] n_category: {ids.n_category}")
        print(f"[category_id_exists] ids.category.address_: {ids.category.address_}")
        print(f"[category_id_exists] ids.category.address_ + ids.Category.data: {hex(memory[ids.category.address_ + ids.Category.data])}")
        print(f"[category_id_exists] ids.category.address_ + ids.Category.data + ids.CategoryData.category_type: {hex(memory[ids.category.address_ + ids.Category.data + ids.CategoryData.category_type])}")
    %}
    if (category.data.category_type == category_id) {
        return (exists = 1, result = 1);
    } else {
        return category_id_exists(category + Category.SIZE, n_category - 1, category_id);
    }
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

func check_category_pubkey_authority(state: State*, category_id: felt, pubkey: felt) -> (root: felt, exists: felt, result: felt) {
    alloc_locals;

    %{
        if True:
            print(f"[check_category_pubkey_authority] ids.state: {ids.state}")
            print(f"[check_category_pubkey_authority] ids.state.address_: {ids.state.address_}")
            print(f"[check_category_pubkey_authority] memory[ids.state.address_]: {memory[ids.state.address_]}")
            # @todo debug here
            print(f"[check_category_pubkey_authority] state.all_category value: {memory[ids.state.all_category.address_]}, state.all_category ref: {ids.state.all_category}")
            category_hash = memory[ids.state.all_category.address_ + ids.Category.SIZE * 0 + ids.Category.hash]
            print(f"[check_category_pubkey_authority] state.all_category hash: {hex(category_hash)}")
            category_data = memory[ids.state.all_category.address_ + ids.Category.SIZE * 0 + ids.Category.data + ids.CategoryData.SIZE * 0 + ids.CategoryData.category_type]
            print(f"[check_category_pubkey_authority] state.all_category data: {hex(category_data)}")
    %}

    let (exists, index) = category_id_exists(state.all_category, state.n_all_category, category_id);

    %{
        if False:
            print(f"exists: {ids.exists}, index: {ids.index}")
            print(f"state.all_category value: {memory[ids.state.all_category.address_]}, state.all_category ref: {ids.state.all_category}")
            category_hash = memory[ids.state.all_category.address_ + ids.Category.SIZE * 0 + ids.Category.hash]
            print(f"state.all_category hash: {hex(category_hash)}")
            category_data = memory[ids.state.all_category.address_ + ids.Category.SIZE * 0 + ids.Category.data + ids.CategoryData.SIZE * 0 + ids.CategoryData.category_type]
            print(f"state.all_category data: {hex(category_data)}")
    %}

    // let n_: felt = [state.all_category + Category.SIZE * 0 + Category.data + CategoryData.SIZE * 0 + CategoryData.category_type];

    tempvar cat: Category* = state.all_category + index * Category.SIZE;
    // tempvar catdata: CategoryData = [cat + Category.data];
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
    // tempvar n_elements: felt = [state.all_category + index * Category.SIZE + Category.data + CategoryData.n_category_elements_child];
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

func copy_elements_by_assert_except_index(
    n_category_elements_child: felt,
    category_elements_child: CategoryElement*,
    new_category_elements_child: CategoryElement*,
    index: felt,
) -> () {
    if (n_category_elements_child == 0){
        return ();
    }
    if (index != n_category_elements_child) {
        assert category_elements_child = new_category_elements_child;
    }
    copy_elements_by_assert_except_index(
        n_category_elements_child - 1,
        category_elements_child + CategoryElement.SIZE,
        new_category_elements_child + CategoryElement.SIZE,
        index,
    );
    return ();
}

func add_node_to_state_by_reference_recursive(
    // current remaining length of category_elements_child
    n_category_elements_child: felt,
    // list of elements to search for
    category_elements_child: CategoryElement*,
    // list of new elements to copy to
    new_category_elements_child: CategoryElement*,
    pubkey: felt,
    node: CategoryElement,
    result: felt,
) -> (result: felt) {
    alloc_locals;
    %{
        print(f"[add_node_to_state_by_reference_recursive] n_category_elements_child: {ids.n_category_elements_child}")
        print(f"[add_node_to_state_by_reference_recursive] pubkey: {hex(ids.pubkey)}")
        # category_elements_child_pubkey = hex(
        #     memory[
        #         ids.category_elements_child.address_ +
        #         ids.CategoryElement.n_category_elements_child +
        #         ids.CategoryElement.category_elements_child +
        #         ids.CategoryElement.depth +
        #         ids.CategoryElement.width +
        #         ids.CategoryElement.pubkey
        #     ]
        # )
        # print(f"[add_node_to_state_by_reference_recursive] category_elements_child.pubkey: {category_elements_child_pubkey}")
    %}
    if (n_category_elements_child == 0){
        // you don't have to do anything in this case. just return given result.
        return (result = result);
    }else{
        // if result is already true, you don't have to do anything. just copy reference data and return given result.
        if (result == 1) {
            assert category_elements_child = new_category_elements_child;
            return (result = result);
        }else{
            // if result is false, selectively copy reference or substitute new node value.
            local result_pk: felt;
            if (category_elements_child.pubkey == pubkey){
                // append node to list of category_elements_child.category_elements_child
                // don't forget to increment n_category_elements_child
                assert [new_category_elements_child.category_elements_child + Category.SIZE * (category_elements_child.n_category_elements_child + 1)] = node;
                // set result as true.
                assert result_pk = 1;
                // copy other elements
                // 1) new_category_elements_child.category_elements_child[ other index ]
                copy_elements_by_assert_except_index(
                    category_elements_child.n_category_elements_child + 1,
                    category_elements_child.category_elements_child,
                    new_category_elements_child.category_elements_child,
                    category_elements_child.n_category_elements_child + 1
                );
                // 2) category_elements_child + 1, ... , category_elements_child + n_category_elements_child
                copy_elements_by_assert_except_index(
                    // you can use remaining count
                    n_category_elements_child - 1,
                    category_elements_child + CategoryElement.SIZE,
                    new_category_elements_child + CategoryElement.SIZE,
                    // copy everything?
                    n_category_elements_child + 1
                );

                return (result = result_pk);
            }else{
                // set result as false;
                assert result_pk = 0;
            }
            // depth first search.
            let (result2) =  add_node_to_state_by_reference_recursive(
                category_elements_child.n_category_elements_child,
                category_elements_child.category_elements_child,
                new_category_elements_child.category_elements_child,
                pubkey,
                node,
                0,
            );
            if (result2 == 1){
                // copy other elements.
                // 1) category_elements_child + 1, ... , category_elements_child + n_category_elements_child
                copy_elements_by_assert_except_index(
                    // you can use remaining count
                    n_category_elements_child - 1,
                    category_elements_child + CategoryElement.SIZE,
                    new_category_elements_child + CategoryElement.SIZE,
                    // copy everything?
                    n_category_elements_child + 1
                );
                // you should also update brother nodes
                return (result = result2);
            }

            let (result1) =  add_node_to_state_by_reference_recursive(
                n_category_elements_child - 1,
                category_elements_child + CategoryElement.SIZE,
                new_category_elements_child + CategoryElement.SIZE,
                pubkey,
                node,
                0,
            );
            // simply, copy information of this node to new array.
            // 1) new_category_elements_child = category_elements_child;
            assert new_category_elements_child = category_elements_child;
            return (result = result1);
        }
    }
}

// use pubkey to find where to attach new node
func add_node_to_state_by_reference(new_data: CategoryData*, data: CategoryData*, pubkey: felt, node: CategoryElement) -> (result: felt) {
    alloc_locals;

    %{
        # ids.CategoryData.category_type + ids.CategoryData.n_category_elements_child
        category_type = memory[ids.data.address_ + ids.CategoryData.category_type ]
        n_category_elements_child = memory[ids.data.address_ + ids.CategoryData.n_category_elements_child]
        print(f"[add_node_to_state_by_reference] data.category_type: {hex(category_type)}")
        print(f"[add_node_to_state_by_reference] data.n_category_elements_child: {n_category_elements_child}")
    %}

    // we will add data? in that case it will be data.n_category_elements_child + 1
    // @todo fix this dirty hack for first data
    if (data.n_category_elements_child == 0){
        assert new_data.n_category_elements_child = data.n_category_elements_child + 1;
    }else{
        assert new_data.n_category_elements_child = data.n_category_elements_child;
    }
    let (category_elements_child: CategoryElement*) = alloc();
    // relate two data by assertion
    assert new_data.category_elements_child = category_elements_child;

    let (result) = add_node_to_state_by_reference_recursive(
        data.n_category_elements_child,
        data.category_elements_child,
        new_data.category_elements_child, // this is empty array, add data!
        pubkey,
        node,
        0
    );
    return (result = result);
}

func verify_transaction_node_create(state: State*, transaction: Transaction) -> (state: State*) {
    alloc_locals;
    let (new_state: State*) = alloc();
    // apply_command_node_create
    tempvar command :felt* = transaction.command;
    tempvar category_id = command[1];
    tempvar depth = command[2];
    tempvar width = command[3];
    tempvar node_pubkey = command[4];
    tempvar pubkey = transaction.pubkey;
    let (root, exists, result) = check_category_pubkey_authority(state, category_id, pubkey);
    %{
        print(f"[verify_transaction_node_create] [] root: {ids.root}")
        print(f"[verify_transaction_node_create] [] exists: {ids.exists}")
        print(f"[verify_transaction_node_create] [] result: {ids.result}")
    %}
    // node create: this pubkey does not have authority over category
    assert (exists - 1) * (root - 1) = 0;
    // nobody exists in category, and root is trying to add first node.
    // or maybe category does not exist at all
    if (exists == 0 and root == 1 and result != -1) {
        tempvar index = result;
        let (child_element: CategoryElement*) = alloc();
        child_element.depth = depth;
        child_element.width = width;
        child_element.pubkey = node_pubkey;

        assert new_state.block_hash = state.block_hash;
        assert new_state.root_pubkey = state.root_pubkey;
        assert new_state.n_all_category = state.n_all_category;

        tempvar n_category_elements_child: felt = [
            cast(state.all_category + Category.SIZE * index  +  Category.data +
                CategoryData.n_category_elements_child,
                felt*
            )
        ];

        // find matching category (by index), then assert that category id has new single element

        // get old reference
        tempvar cat: Category* = state.all_category + Category.SIZE * index;

        let (new_cat: Category*) = alloc();
        local new_catdata: CategoryData;
        assert new_catdata.category_type = cat.data.category_type;
        assert new_catdata.n_category_elements_child = n_category_elements_child + 1;
        // category_elements_child must be alloc'd and new node must be copied to it

        tempvar category_elements_child: CategoryElement* = cast(
            state.all_category + Category.SIZE * index  +  Category.data +
            CategoryData.category_elements_child,
            CategoryElement*
        );
        let (new_category_elements_child: CategoryElement*) = alloc();
        // example assert
        // if (index == 0){
        //     assert new_catdata.category_elements_child = child_element;
        // } else {
        //     assert new_catdata.category_elements_child = category_elements_child;
        // }
        //

        %{
            print(f"[verify_transaction_node_create] [] category_elements_child: {ids.category_elements_child.address_}")
            print(f"[verify_transaction_node_create] [] new_category_elements_child: {ids.new_category_elements_child.address_}")
        %}
        copy_elements_by_assert_except_index(
            // this is length
            n_category_elements_child + 1,
            // old elements
            category_elements_child,
            // new elements
            new_category_elements_child,
            // new_catdata.category_elements_child,
            // this is zero-index, (n_category_elements_child+1)-th element is already allocated so skipped.
            n_category_elements_child
        );
        assert new_catdata.category_elements_child = new_category_elements_child;
        // CategoryElement* size is 1, not CategoryElement.SIZE
        assert new_catdata.category_elements_child + CategoryElement.SIZE * (n_category_elements_child) = child_element;


        assert new_cat.data = new_catdata;
        assert new_cat.hash = 0;
    

        let (state_2: State*) = assign_update_state_category_recursive(new_state, state.all_category, index, new_cat, 0);

        return (state = state_2);
    }
    // even root should first create category by himself.
    // assert (exists * exists) + ((root - 1) * (root - 1)) + ((result + 1) * (result + 1)) != 0;
    if (exists == 0 and root == 1 and result == -1) {
        // always fail here.
        assert 0 = 1;
    }
    // category pubkey already exists and non-root pubkey is trying to add node
    if (root == 0) {
        tempvar index = result;
        let (empty_child_reference: CategoryElement*) = alloc();
        tempvar child: CategoryElement;
        child.depth = depth;
        child.width = width;
        child.pubkey = node_pubkey;
        child.n_category_elements_child = 0;
        child.category_elements_child = empty_child_reference;
        // @todo implement add_node_to_state_by_reference
        assert new_state.block_hash = state.block_hash;
        assert new_state.root_pubkey = state.root_pubkey;
        assert new_state.n_all_category = state.n_all_category;
        assert new_state.all_category = state.all_category;
        let (new_category_data: CategoryData*) = alloc();

        %{
            print(f"[verify_transaction_node_create] [non-root] index: {ids.index}")
            print(f"[verify_transaction_node_create] [non-root] exists: {ids.exists}")
            print(f"[verify_transaction_node_create] [non-root] result: {ids.result}")
            print(f"[verify_transaction_node_create] [non-root] root: {ids.root}")
            # is it category type?
            category_pointer =  memory[ids.state.all_category.address_ + ids.Category.SIZE * ids.index]
            print(f"[verify_transaction_node_create] [non-root] category_pointer: {hex(category_pointer)}")
            category_data_pointer =  memory[ids.state.all_category.address_ + ids.Category.SIZE * ids.index + ids.Category.data]
            print(f"[verify_transaction_node_create] [non-root] category_data_pointer: {hex(category_data_pointer)}")
            category_data_1 =  memory[ids.state.all_category.address_ + ids.Category.SIZE * ids.index + ids.Category.data + ids.CategoryData.category_type]
            print(f"[verify_transaction_node_create] [non-root] category_data_1(category_type): {hex(category_data_1)}")
            category_data_2 =  memory[ids.state.all_category.address_ + ids.Category.SIZE * ids.index + ids.Category.data + ids.CategoryData.n_category_elements_child]
            print(f"[verify_transaction_node_create] [non-root] category_data_2(n_category_elements_child): {hex(category_data_2)}")
        %}

        let (node_add_result) = add_node_to_state_by_reference(
            new_category_data,
            // state.all_category[index].data
            // +1 is for category.hash
            cast(state.all_category + Category.SIZE * index + Category.data, CategoryData*),
            pubkey,
            child
        );
        
        // verify add result is true
        assert node_add_result = 1;
    } else {
        // category pubkey already exists and root pubkey is trying to add node to category
        // add first node under category
        tempvar index = result;
        let (child_element: CategoryElement*) = alloc();
        child_element.depth = depth;
        child_element.width = width;
        child_element.pubkey = node_pubkey;
        // @todo add by reference
        assert new_state.block_hash = state.block_hash;
        assert new_state.root_pubkey = state.root_pubkey;
        assert new_state.n_all_category = state.n_all_category;
        assert new_state.all_category = state.all_category;

        %{
            print(f"[verify_transaction_node_create] [root] index: {ids.index}")
            print(f"[verify_transaction_node_create] [root] exists: {ids.exists}")
            print(f"[verify_transaction_node_create] [root] result: {ids.result}")
            print(f"[verify_transaction_node_create] [root] root: {ids.root}")
        %}

        return update_state_category(new_state, index, 1, child_element);
    }
    return (state = new_state);
}
func verify_transaction_node_remove(state: State*, transaction: Transaction) -> (state: State*) {
    alloc_locals;
    let (new_state: State*) = alloc();
    return (state = state);
}
func verify_transaction_category_create(state: State*, transaction: Transaction) -> (state: State*) {
    alloc_locals;
    let (new_state: State*) = alloc();
    return (state = state);
}
func verify_transaction_category_remove(state: State*, transaction: Transaction) -> (state: State*) {
    alloc_locals;
    let (new_state: State*) = alloc();
    return (state = state);
}

func verify_transaction(state: State*, transaction: Transaction) -> (state: State*) {
    // verify signature here.
    tempvar pubkey = transaction.pubkey;
    if ([transaction.command] == COMMAND_NODE_CREATE) {

        %{
            if True:
                print(f"[verify_transaction] ids.state: {ids.state}")
                print(f"[verify_transaction] ids.state.address_: {ids.state.address_}")
                print(f"[verify_transaction] memory[ids.state.address_]: {memory[ids.state.address_]}")
        %}    

        return verify_transaction_node_create(state, transaction);
    }else{
        if ([transaction.command] == COMMAND_NODE_REMOVE){
            return verify_transaction_node_remove(state, transaction);
        }else {
            if ([transaction.command] == COMMAND_CATEGORY_CREATE){
                return verify_transaction_category_create(state, transaction);
            }else{
                if ([transaction.command] == COMMAND_CATEGORY_REMOVE){
                    return verify_transaction_category_remove(state, transaction);
                }else{
                    // raise error
                    %{
                        print(f"transaction.msg_hash: {hex(ids.transaction.msg_hash)}")
                        print(f"transaction.command: {ids.transaction.command}")
                        print(f"transaction.n_command: {ids.transaction.n_command}")
                    %}
                    assert 0 = 1;
                }
            } 
        }
    }
    return (state = state);
}

func verify_transaction_recursive(state: State*, n_transactions: felt, transactions: Transaction*) -> (state: State*) {
    alloc_locals;
    if (n_transactions == 0){
        return (state = state);
    }else{
        %{
            if True:
                print(f"[verify_transaction_recursive] {ids.n_transactions} ids.state: {ids.state}")
                print(f"[verify_transaction_recursive] {ids.n_transactions} ids.state.address_: {ids.state.address_}")
                print(f"[verify_transaction_recursive] {ids.n_transactions} memory[ids.state.address_]: {memory[ids.state.address_]}")
                # 
                # root_pubkey: felt,
                # all_category_hash: felt,
                print(f"[verify_transaction_recursive] {ids.n_transactions} root_pubkey: {hex(memory[ids.state.address_ + ids.State.root_pubkey ])}")
                print(f"[verify_transaction_recursive] {ids.n_transactions} n_all_category: {hex(memory[ids.state.address_ + ids.State.n_all_category ])}")
        %}

        let (new_state: State*) = verify_transaction(state, transactions[0]);
        return verify_transaction_recursive(new_state, n_transactions - 1, transactions + Transaction.SIZE);    
    }
}

func assign_felt_array(addr: felt*, n_element: felt, element: felt*) -> felt* {
    if (n_element == 0){
        return addr;
    }else{
        assert [addr] = [element];
        return assign_felt_array(addr + 1, n_element - 1, element + 1);
    }
}

func calc_transactions_merkle_root_rec{hash_ptr: HashBuiltin*}(transaction: Transaction*, transaction_hash: felt*, n_transaction: felt) -> felt* {
    alloc_locals;
    // local felt_array: felt*;
    let (felt_array: felt*) = alloc();
    if (n_transaction == 0){
        return (felt_array);
    }
    // verify transaction.msg_hash

    // allocate array for hash chain of command
    let (command_ptr) = alloc();
    assert [command_ptr] = transaction.n_command;
    // assign transaction.command after [command_ptr + 1].
    assign_felt_array(command_ptr+1, transaction.n_command, transaction.command);

    let (command_hash) = hash_chain(command_ptr);
    let (msg_hash) = hash2(command_hash, transaction.prev_block_hash);
    %{
        if False:
            print(f"command_ptr: {ids.command_ptr}")
            print(f"command_ptr: {hex(memory[ids.command_ptr])}")
            print(f"command_ptr: {hex(memory[ids.command_ptr + 1])}")
            print(f"command_ptr: {hex(memory[ids.command_ptr + 2])}")
            print(f"command_hash: {hex(ids.command_hash)}, msg_hash: {hex(ids.msg_hash)}, transaction.msg_hash: {hex(ids.transaction.msg_hash)}, transaction.prev_block_hash: {hex(ids.transaction.prev_block_hash)}")
    %}
    assert msg_hash = transaction.msg_hash;

    // Allocate an array.
    let (ptr) = alloc();

    // Populate values in the array.
    assert [ptr] = 4;
    assert [ptr + 1] = transaction.msg_hash;
    assert [ptr + 2] = transaction.signature_r;
    assert [ptr + 3] = transaction.signature_s;
    assert [ptr + 4] = transaction.pubkey;

    let (h) = hash_chain(ptr);
    assert transaction_hash[0] = h;
    return calc_transactions_merkle_root_rec(transaction + Transaction.SIZE, transaction_hash + 1, n_transaction - 1);
}

func calc_transactions_merkle_root{hash_ptr: HashBuiltin*}(transactions: Transaction*, n_transactions: felt) -> felt {
    alloc_locals;
    let (transaction_hashes: felt*) = alloc();
    calc_transactions_merkle_root_rec(transactions, transaction_hashes, n_transactions);

    let (transaction_hashes_ptr) = alloc();
    assert [transaction_hashes_ptr] = n_transactions;
    assign_felt_array(transaction_hashes_ptr+1, n_transactions, transaction_hashes);

    let (h) = hash_chain(transaction_hashes_ptr);
    return h;
}
// verify block hash and signature.
func verify_block{hash_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*}(state:State*, block: Block*){
    // check block authenticity except for transaction validity.
    let transactions_merkle_root_recalc = calc_transactions_merkle_root(block.transactions, block.n_transactions);
    assert block.transactions_merkle_root = transactions_merkle_root_recalc;
    let (block_hash) = hash2(transactions_merkle_root_recalc, block.timestamp);
    verify_ecdsa_signature(
        message=block_hash,
        public_key=block.pubkey,
        signature_r=block.signature_r,
        signature_s=block.signature_s,
    );
    return ();
}

func update_block{hash_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*}(state: State*, block: Block*) -> (state: State*) {
    alloc_locals;
    // check if block itself has correct signature, timestamp and block reference.
    // lookup CATEGORY_BLOCK table and if pubkey is correct.
    verify_block(state, block);
    // check contents of block (txs) are correct.
    let (new_state) = verify_transaction_recursive(state, block.n_transactions,  block.transactions);
    return (state=new_state);
}

func update_block_recursive{hash_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*}(state: State*, n_blocks: felt, blocks: Block*) -> (state: State*) {
    alloc_locals;
    if (n_blocks == 0){
        return (state=state);
    }else{
        let (new_state) = update_block(state, blocks);
        return update_block_recursive(new_state, n_blocks - 1, blocks + Block.SIZE);    
    }
}

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

func main{
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*
}() {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();
    // given list of block, update state
    local initial_state: State;
    local initial_hash: felt;
    local n_blocks: felt;
    let (blocks: Block*) = alloc();
    local final_state: State; // latest_state should be hardcoded, also get verified by verifier.
    local final_hash: felt;
    let (transactions: Transaction*) = alloc();
    let (root_messages: RootMessage*) = alloc();
    local commands: felt*;

    let (initial_state_categories: Category*) = alloc();
    let (initial_state_category_elements: CategoryElement*) = alloc();
    let (final_state_categories: Category*) = alloc();
    let (final_state_category_elements: CategoryElement*) = alloc();

    %{
        # assign state variable from input json. it could be initial state.
        # assign blocks variable from input json
        ids.initial_hash = int(program_input["initial_hash"], 16)
        ids.final_hash = int(program_input["final_hash"], 16)
        ids.n_blocks = len(program_input["blocks"])

        # transaction total count
        # transaction is Transaction struct. 
        transactions_count = 0
        # root message total count
        # root_message is RootMessage struct.
        root_messages_count = 0
        # command total count
        # commands is felt array.
        commands_count = 0
        commands_addr = segments.add()
        ids.commands = commands_addr

        # blocks
        for block_index in range(len(program_input["blocks"])):
            base_addr = ids.blocks.address_ + ids.Block.SIZE * block_index
            block = program_input["blocks"][block_index]
            memory[base_addr + ids.Block.n_transactions] = len(block["transactions"])
            memory[base_addr + ids.Block.transactions_merkle_root] = int(block["transactions_merkle_root"], 16)
            memory[base_addr + ids.Block.timestamp] = block["timestamp"]
            memory[base_addr + ids.Block.signature_r] = int(block["signature_r"], 16)
            memory[base_addr + ids.Block.signature_s] = int(block["signature_s"], 16)
            memory[base_addr + ids.Block.pubkey] = int(block["pubkey"], 16)

            # assign transaction address value to reference
            memory[base_addr + ids.Block.transactions] = ids.transactions.address_ + ids.Transaction.SIZE * transactions_count

            # fill in transactions
            for tx_index in range(len(block["transactions"])):
                tx_base_addr = ids.transactions.address_ + ids.Transaction.SIZE * (transactions_count + tx_index)
                tx = block["transactions"][tx_index]
                memory[tx_base_addr + ids.Transaction.prev_block_hash] = int(tx["prev_block_hash"], 16)
                memory[tx_base_addr + ids.Transaction.command_hash] = int(tx["command_hash"], 16)
                memory[tx_base_addr + ids.Transaction.msg_hash] = int(tx["msg_hash"], 16)
                memory[tx_base_addr + ids.Transaction.signature_r] = int(tx["signature_r"], 16)
                memory[tx_base_addr + ids.Transaction.signature_s] = int(tx["signature_s"], 16)
                memory[tx_base_addr + ids.Transaction.pubkey] = int(tx["pubkey"], 16)

                # command is given as array so it shold be assigned to another memory space.
                memory[tx_base_addr + ids.Transaction.n_command] = len(tx["command"])
                commands = list(map(lambda el: int(el, 16), tx["command"]))
                # assign commands to reference
                memory[tx_base_addr + ids.Transaction.command] = commands_addr + commands_count
                for command_index in range(len(commands)):
                    command_base_addr = commands_addr + (commands_count + command_index)
                    command = commands[command_index]
                    memory[command_base_addr] = command
                # update command count data
                commands_count += len(commands)

            # update transaction count data
            transactions_count += len(block["transactions"])
                    
            # assign root messages to reference
            memory[base_addr + ids.Block.root_message] = ids.root_messages.address_ + ids.RootMessage.SIZE * root_messages_count
            # fill in root message array
            for root_message_index in range(len(block["root_message"])):
                root_message_base_addr = ids.root_messages.address_ + ids.RootMessage.SIZE * (root_messages_count + root_message_index)
                root_message = block["root_message"][root_message_index]
                memory[root_message_base_addr] = root_message
            # update root messages count data
            root_messages_count += len(block["root_message"])


        
    %}
    // states
    %{
        # elements_base_addr is where reference is stored.
        # input_category_elements is json data given as input.
        # category_elements_address is a base address for elements memory location
        # category_elements_count is maximum memory index where elements are located.
        # return new category_elements_count
        def copy_category_elements_by_ref(elements_base_addr: int, input_category_elements, category_elements_address:int, _category_elements_count: int) -> int:
            category_elements_count = _category_elements_count
            if len(input_category_elements) == 0:
                return category_elements_count
            else:
                memory[elements_base_addr] = category_elements_address + ids.CategoryElement.SIZE * category_elements_count
                for element_index in range(len(input_category_elements)):
                    element_base_addr = category_elements_address + ids.CategoryElement.SIZE * (category_elements_count)
                    memory[element_base_addr + ids.CategoryElement.depth] = input_category_elements[element_index]["depth"]
                    memory[element_base_addr + ids.CategoryElement.width] = input_category_elements[element_index]["width"]
                    memory[element_base_addr + ids.CategoryElement.pubkey] = int(input_category_elements[element_index]["pubkey"], 16)
                    memory[element_base_addr + ids.CategoryElement.n_category_elements_child] = len(input_category_elements[element_index]["category_elements_child"])                    

                    category_elements_count += 1

                    category_elements_count = copy_category_elements_by_ref(
                        element_base_addr + ids.CategoryElement.category_elements_child,
                        # category_elements[element_index].category_elements_child,
                        input_category_elements[element_index]["category_elements_child"],
                        category_elements_address,
                        category_elements_count,
                    )

                return category_elements_count

        # initial state
        initial_state_addr = ids.initial_state.address_
        initial_state = program_input["initial_state"]
        memory[initial_state_addr + ids.State.root_pubkey] = int(initial_state["state"]["root_pubkey"], 16)
        memory[initial_state_addr + ids.State.all_category_hash] = int(initial_state["state"]["all_category_hash"], 16)
        memory[initial_state_addr + ids.State.block_hash] = int(initial_state["block_hash"], 16)
        memory[initial_state_addr + ids.State.n_all_category] = len(initial_state["state"]["all_category"])

        # assign initial_state_categories address value to reference
        memory[initial_state_addr + ids.State.all_category] = ids.initial_state_categories.address_
        initial_state_category_elements_count = 0

        # ids.initial_state.all_category = []
        for category_index in range(len(initial_state["state"]["all_category"])):
            category_base_addr = ids.initial_state_categories.address_ + ids.Category.SIZE * category_index
            memory[category_base_addr + ids.Category.hash] = int(initial_state["state"]["all_category"][category_index]["hash"], 16)
            memory[category_base_addr + ids.Category.data + ids.CategoryData.category_type] = int(initial_state["state"]["all_category"][category_index]["data"]["category_type"], 16)
            memory[category_base_addr + ids.Category.data + ids.CategoryData.n_category_elements_child] = initial_state["state"]["all_category"][category_index]["data"]["n_category_elements_child"]

            memory[category_base_addr + ids.Category.data + ids.CategoryData.category_elements_child] = ids.initial_state_category_elements.address_ + (initial_state_category_elements_count) * ids.CategoryElement.SIZE
            elements_base_addr = category_base_addr + ids.Category.data + ids.CategoryData.category_elements_child
            initial_state_category_elements_count = copy_category_elements_by_ref(
                elements_base_addr,
                # ids.initial_state.all_category[category_index].data.category_elements_child,
                initial_state["state"]["all_category"][category_index]["data"]["category_elements_child"],
                ids.initial_state_category_elements.address_,
                initial_state_category_elements_count,
            )

        # final state
        final_state_addr = ids.final_state.address_
        final_state = program_input["final_state"]
        memory[final_state_addr + ids.State.root_pubkey] = int(final_state["state"]["root_pubkey"], 16)
        memory[final_state_addr + ids.State.all_category_hash] = int(final_state["state"]["all_category_hash"], 16)
        memory[final_state_addr + ids.State.block_hash] = int(final_state["block_hash"], 16)
        memory[final_state_addr + ids.State.n_all_category] = len(final_state["state"]["all_category"])

        # assign final_state_categories address value to reference
        memory[final_state_addr + ids.State.all_category] = ids.final_state_categories.address_
        final_state_category_elements_count = 0

        # ids.final_state.all_category = []
        for category_index in range(len(final_state["state"]["all_category"])):
            category_base_addr = ids.final_state_categories.address_ + ids.Category.SIZE * category_index
            memory[category_base_addr + ids.Category.hash] = int(final_state["state"]["all_category"][category_index]["hash"], 16)
            memory[category_base_addr + ids.Category.data + ids.CategoryData.category_type] = int(final_state["state"]["all_category"][category_index]["data"]["category_type"], 16)
            memory[category_base_addr + ids.Category.data + ids.CategoryData.n_category_elements_child] = final_state["state"]["all_category"][category_index]["data"]["n_category_elements_child"]

            memory[category_base_addr + ids.Category.data + ids.CategoryData.category_elements_child] = ids.final_state_category_elements.address_ + (final_state_category_elements_count) * ids.CategoryElement.SIZE
            elements_base_addr = category_base_addr + ids.Category.data + ids.CategoryData.category_elements_child
            final_state_category_elements_count = copy_category_elements_by_ref(
                elements_base_addr,
                # ids.final_state.all_category[category_index].data.category_elements_child,
                final_state["state"]["all_category"][category_index]["data"]["category_elements_child"],
                ids.final_state_category_elements.address_,
                final_state_category_elements_count,
            )

    %}


    %{
        if True:
            print(f"ids.initial_state: {ids.initial_state}")
            print(f"ids.initial_state.address_: {ids.initial_state.address_}")
            print(f"memory[ids.initial_state.address_]: {memory[ids.initial_state.address_]}")
    %}


    let (updated_state: State*) = update_block_recursive{hash_ptr = pedersen_ptr}(cast(&initial_state, State*), n_blocks, blocks);
    // assert that updated_state and latest_state match!
    let updated_hash = recompute_state_hash{hash_ptr = pedersen_ptr}(updated_state);
    assert updated_hash = final_hash;

    return ();
}
