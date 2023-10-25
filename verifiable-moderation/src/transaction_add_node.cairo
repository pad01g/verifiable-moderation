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

from src.transaction_common import (
    update_state_category,
    check_category_pubkey_authority,
    assign_update_state_category_recursive,
)

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
        print(f"[add_node_to_state_by_reference_recursive] result: {hex(ids.result)}")
        print(f"[add_node_to_state_by_reference_recursive] category_elements_child.pubkey: {hex(memory[ids.category_elements_child.address_ + ids.CategoryElement.pubkey])}")
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
                    assert new_category_elements_child.n_category_elements_child = 1;
                }else{
                    assert new_category_elements_child.n_category_elements_child = category_elements_child.n_category_elements_child + 1;
                }
                assert new_category_elements_child.category_elements_child[category_elements_child.n_category_elements_child] = [node];
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

                // copy current element
                assert new_category_elements_child.pubkey = category_elements_child.pubkey;
                assert new_category_elements_child.depth = category_elements_child.depth;
                assert new_category_elements_child.width = category_elements_child.width;
                
                return (result = result_pk);
            }else{
                // set result as false;
                assert result_pk = 0;
            }
            // depth first search.
            if (category_elements_child.n_category_elements_child != 0){

                let (ce: CategoryElement*) = alloc();
                assert new_category_elements_child.pubkey = category_elements_child.pubkey;
                assert new_category_elements_child.depth = category_elements_child.depth;
                assert new_category_elements_child.width = category_elements_child.width;
                assert new_category_elements_child.n_category_elements_child = category_elements_child.n_category_elements_child;
                assert new_category_elements_child.category_elements_child = ce;

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
                    // copy current element
                    // assert new_category_elements_child = category_elements_child;
    
                    // you should also update brother nodes
                    return (result = result2);
                }
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
    local category_id = command[1];
    local depth = command[2];
    local width = command[3];
    local node_pubkey = command[4];
    local pubkey = transaction.pubkey;
    let (root, exists, result) = check_category_pubkey_authority(state, category_id, pubkey);
    %{
        print(f"[verify_transaction_node_create] root: {ids.root}")
        print(f"[verify_transaction_node_create] exists: {ids.exists}")
        print(f"[verify_transaction_node_create] result: {ids.result}")
        print(f"[verify_transaction_node_create] category_id: {hex(ids.category_id)}")
        print(f"[verify_transaction_node_create] pubkey: {hex(ids.pubkey)}")
        print(f"[verify_transaction_node_create] node_pubkey: {hex(ids.node_pubkey)}")
        print(f"[verify_transaction_node_create] depth: {hex(ids.depth)}")
        print(f"[verify_transaction_node_create] width: {hex(ids.width)}")
    %}
    // node create: this pubkey does not have authority over category
    assert (exists - 1) * (root - 1) = 0;
    // nobody exists in category, and root is trying to add first node.
    // or maybe category does not exist at all
    if (exists == 0 and root == 1 and result != -1) {
        tempvar index = result;
        let (child_element: CategoryElement*) = alloc();
        assert child_element.depth = depth;
        assert child_element.width = width;
        assert child_element.pubkey = node_pubkey;
        let (child_element_2: CategoryElement*) = alloc();
        assert child_element.category_elements_child = child_element_2;
        assert child_element.n_category_elements_child = 0;

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
        assert new_cat.hash = 1;
    

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
        let (all_category: Category*) = alloc();
        assert new_state.all_category = all_category;

        let (new_category_data: CategoryData*) = alloc();
        // let (new_category_data_child: CategoryElement*) = alloc();
        assert new_category_data.category_type = category_id;
        // assert new_category_data.category_elements_child = new_category_data_child;

        local data: CategoryData* = cast(state.all_category + Category.SIZE * index + Category.data, CategoryData*);

        // this value should never be data.n_category_elements_child + 1
        // because it's top level and only root can add top level nodes
        assert new_category_data.n_category_elements_child = data.n_category_elements_child;
        let (category_elements_child: CategoryElement*) = alloc();
        // relate two data by assertion
        assert new_category_data.category_elements_child = category_elements_child;


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
            data,
            pubkey,
            child
        );
        // verify add result is true
        assert node_add_result = 1;

        let (new_cat: Category*) = alloc();
        assert new_cat.hash = 2;
        assert new_cat.data = [new_category_data];

        // new_category_data is updated now, apply it to state var.
        let (state_2: State*) = assign_update_state_category_recursive(
            new_state,
            state.all_category,
            index,
            new_cat,
            0
        );
        return (state = state_2);

    } else {
        // category pubkey already exists and root pubkey is trying to add node to category
        // add first node under category
        tempvar index = result;
        let (child_element: CategoryElement*) = alloc();
        assert child_element.depth = depth;
        assert child_element.width = width;
        assert child_element.pubkey = node_pubkey;
        let (child_element_2: CategoryElement*) = alloc();
        assert child_element.category_elements_child = child_element_2;
        assert child_element.n_category_elements_child = 0;

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
}
