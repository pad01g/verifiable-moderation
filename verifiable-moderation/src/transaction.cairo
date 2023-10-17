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
