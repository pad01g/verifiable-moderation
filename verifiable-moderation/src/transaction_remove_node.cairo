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
    check_category_pubkey_authority,
    update_state_category,
)

func assign_category_without_pubkey(src_category_list_length: felt, src_category_list: CategoryElement*, dst_category_list: CategoryElement*, pubkey: felt) -> () {
    if (src_category_list_length == 0){
        return ();
    }
    tempvar pointer: CategoryElement*;
    if (src_category_list.pubkey == pubkey){
        // skip
        pointer = src_category_list;
    }else{
        assert [dst_category_list] = [src_category_list];
        pointer = src_category_list + CategoryElement.SIZE;
    }
    return assign_category_without_pubkey(
        src_category_list_length - 1,
        src_category_list + CategoryElement.SIZE,
        pointer,
        pubkey,
    );
}

// search for transaction issuer pubkey.
// then, under the pubkey node, search for target pubkey and remove it ( `search_and_remove_node_from_state` )
func remove_node_from_state_by_reference_recursive(
    // current remaining length of category_elements_child
    n_category_elements_child: felt,
    // list of elements to search for
    category_elements_child: CategoryElement*,
    // list of new elements to copy to
    new_category_elements_child: CategoryElement*,
    // transaction issuer pubkey
    pubkey: felt,
    // target pubkey to delete
    target_pubkey: felt,
    result: felt,
) -> (result: felt) {
    alloc_locals;
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
                // remove child elements recursively under this element.
                // but first you need to find it...
                // copy `category_elements_child.category_elements_child` to `new_category_elements_child.category_elements_child`
                // without removed element in `search_and_remove_node_from_state`.
                search_and_remove_node_from_state_same_level(
                    category_elements_child.n_category_elements_child,
                    category_elements_child.category_elements_child,
                    new_category_elements_child.category_elements_child,
                    target_pubkey
                );

                // set result as true.
                assert result_pk = 1;

                return (result = result_pk);
            }else{
                // set result as false;
                assert result_pk = 0;
            }
            // depth first search.
            let (result2) =  remove_node_from_state_by_reference_recursive(
                category_elements_child.n_category_elements_child,
                category_elements_child.category_elements_child,
                new_category_elements_child.category_elements_child,
                pubkey,
                target_pubkey,
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

            let (result1) =  remove_node_from_state_by_reference_recursive(
                n_category_elements_child - 1,
                category_elements_child + CategoryElement.SIZE,
                new_category_elements_child + CategoryElement.SIZE,
                pubkey,
                target_pubkey,
                0,
            );
            // simply, copy information of this node to new array.
            // 1) new_category_elements_child = category_elements_child;
            assert new_category_elements_child = category_elements_child;
            return (result = result1);
        }
    }
}

func verify_transaction_node_remove(state: State*, transaction: Transaction) -> (state: State*) {
    alloc_locals;
    let (new_state: State*) = alloc();
    tempvar category_id = command[1];
    tempvar node_pubkey = command[2];
    let (root, exists, result) = check_category_pubkey_authority(state, category_id, transaction.pubkey);
    if (exists == 0){
        // cannot remove.
        assert 0 = 1;
    }else{
        if (root == 1){
            // remove node from category root
            assert new_state.block_hash = state.block_hash;
            assert new_state.root_pubkey = state.root_pubkey;
            assert new_state.n_all_category = state.n_all_category;
            let (new_category_elements: CategoryElement*) = alloc();
            
            assign_category_without_pubkey(
                state.all_category[result].data.n_category_elements_child,
                state.all_category[result].data.category_elements_child,
                new_category_elements,
                node_pubkey
            );

            // update category
            let (state_2: State*) = update_state_category(
                new_state,
                result,
                new_state.all_category[result].data.n_category_elements_child - 1,
                new_category_elements
            );
            return (state = state_2);
    
        }else{
            // search pubkey from tree object and remove.
            // remove_node_from_state_by_reference_recursive
        }
    }

    return (state = state);
}