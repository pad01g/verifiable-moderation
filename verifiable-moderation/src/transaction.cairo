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
    category_id_exists,
    search_tree_pubkey_recursive,
    update_state_category
)

from src.transaction_add_node import (
    verify_transaction_node_create,
)

from src.transaction_remove_node import (
    verify_transaction_node_remove,
)

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
