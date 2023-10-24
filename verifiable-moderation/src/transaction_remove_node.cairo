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
    check_category_pubkey_authority,
    update_state_category,
)

struct LoopVariables {
    new_category_list: CategoryElement*,
    new_category_list_index: felt,
    category_list: CategoryElement*,
    pubkey: felt,
    auth_pubkey: felt,
    authorized: felt,
}

struct ListWithLength {
    list: CategoryElement*,
    length: felt,
}

func assign_category_without_pubkey(src_category_list_length: felt, src_category_list: CategoryElement*, dst_category_list: CategoryElement*, pubkey: felt) -> () {
    alloc_locals;
    if (src_category_list_length == 0){
        return ();
    }
    let (pointer: CategoryElement*) = alloc();
    if (src_category_list.pubkey == pubkey){
        // skip
        assert pointer = src_category_list;
    }else{
        assert [dst_category_list] = [src_category_list];
        assert pointer = src_category_list + CategoryElement.SIZE;
    }
    return assign_category_without_pubkey(
        src_category_list_length - 1,
        src_category_list + CategoryElement.SIZE,
        pointer,
        pubkey,
    );
}


func for_loop_inside(vars: LoopVariables, current: felt) -> LoopVariables {
    alloc_locals;
    tempvar category_list_current_authorized;
    if (vars.category_list[current].pubkey == vars.auth_pubkey){
        assert category_list_current_authorized = 1;
    }else{
        assert category_list_current_authorized = 0;
    }

    local new_category_list_index;
    if (vars.category_list[current].pubkey == vars.pubkey){

        if (vars.authorized == 1){
            // you can safely remove if authorized
            assert new_category_list_index = vars.new_category_list_index;
        }else{
            // permission error. not authorized and found pubkey.
            assert 0 = 1;
        }
    }else{

        tempvar authorized;
        if (vars.authorized == 1){
            assert authorized = 1;
        }else{
            assert authorized = category_list_current_authorized;
        }

        // ListWithLength
        let filtered = remove_node_from_state_by_reference_recursive_noloop(
            vars.category_list[current].category_elements_child,
            vars.category_list[current].n_category_elements_child,
            vars.pubkey,
            vars.auth_pubkey,
            authorized,
        );

        let new_list = CategoryElement(
            n_category_elements_child = filtered.length,
            category_elements_child = filtered.list,
            depth = vars.category_list[current].depth,
            width = vars.category_list[current].width,
            pubkey = vars.category_list[current].pubkey,
        );

        assert vars.new_category_list[vars.new_category_list_index] = new_list;
        assert new_category_list_index = vars.new_category_list_index + 1;
    }

    let new_vars = LoopVariables(
        new_category_list = vars.new_category_list,
        new_category_list_index = new_category_list_index,
        category_list = vars.category_list,
        pubkey = vars.pubkey,
        auth_pubkey = vars.auth_pubkey,
        authorized = vars.authorized,
    );
    return new_vars;
}

func for_loop(vars: LoopVariables, max: felt, current: felt) -> ListWithLength {
    if (max == current) {
        let list = ListWithLength(
            list = vars.new_category_list,
            length =  vars.new_category_list_index,
        );


        %{
            if True:
                print(f"[transaction_remove_node][for_loop] vars.new_category_list_index: {memory[ids.vars.address_ + ids.LoopVariables.new_category_list_index]}")
        %}
        return list;
    }
    let new_vars = for_loop_inside(vars, current);
    return for_loop(new_vars, max, current + 1);
}

func remove_node_from_state_by_reference_recursive_noloop(
    category_list: CategoryElement*,
    category_list_length: felt,
    pubkey: felt,
    auth_pubkey: felt,
    authorized: felt,
) -> ListWithLength {
    let (new_category_list: CategoryElement*) = alloc();
    let new_category_list_index = 0;
    let vars = LoopVariables(
        new_category_list = new_category_list,
        new_category_list_index = new_category_list_index,
        category_list = category_list,
        pubkey = pubkey,
        auth_pubkey = auth_pubkey,
        authorized = authorized,
    );
    let list = for_loop(vars, category_list_length, 0);

    %{
        if True:
            print(f"[transaction_remove_node][remove_node_from_state_by_reference_recursive_noloop] list.length: {memory[ids.list.address_ + ids.ListWithLength.length]}")
    %}
    return list;
}

func verify_transaction_node_remove(state: State*, transaction: Transaction) -> (state: State*) {
    alloc_locals;
    let (new_state: State*) = alloc();
    tempvar category_id = transaction.command[1];
    tempvar node_pubkey = transaction.command[2];
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
            // remove_node_from_state_by_reference_recursive();
            tempvar auth_pubkey = transaction.pubkey;
            tempvar authorized = 0;
            let filtered: ListWithLength = remove_node_from_state_by_reference_recursive_noloop(
                state.all_category[result].data.category_elements_child,
                state.all_category[result].data.n_category_elements_child,
                node_pubkey,
                auth_pubkey,
                authorized,
            );
            let (new_state: State*) = update_state_category(
                state,
                result,
                filtered.length,
                filtered.list,
            );
            return (state = new_state);
        }
    }

    return (state = state);
}