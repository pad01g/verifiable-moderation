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

from src.transaction import (
    update_state_category,
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
    node: CategoryElement*,
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
                if (category_elements_child.n_category_elements_child == 0){
                    // if `new_category_elements_child.category_elements_child` is not defined, it should be allocated first.
                    let (child: CategoryElement*) = alloc();
                    assert new_category_elements_child.category_elements_child = child;
                }
                assert [new_category_elements_child.category_elements_child + CategoryElement.SIZE * (category_elements_child.n_category_elements_child)] = [node];
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
func add_node_to_state_by_reference(new_data: CategoryData*, data: CategoryData*, pubkey: felt, node: CategoryElement*) -> (result: felt) {
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
        let (child: CategoryElement*) = alloc();
        assert child.depth = depth;
        assert child.width = width;
        assert child.pubkey = node_pubkey;
        assert child.n_category_elements_child = 0;
        assert child.category_elements_child = empty_child_reference;
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