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

from src.structs import (
    State,
    CategoryElement,
    CategoryData,
    Category,
    Block,
    RootMessage,
    Transaction,
)
from src.block import (
    update_block_recursive,
)
from src.hash import (
    recompute_state_hash,
)

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
