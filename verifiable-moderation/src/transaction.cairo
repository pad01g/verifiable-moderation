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
