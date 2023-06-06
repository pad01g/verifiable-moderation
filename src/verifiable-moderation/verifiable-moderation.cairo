struct State {
    root_pubkey: felt,
    category_merkle_root: felt,
    category_list: Category*, // hashN(category_list[0].edge_merkle_root, ..., category_list[N-1].edge_merkle_root)
    timestamp: felt,
}

struct Category {
    category_id: felt,
    edge_merkle_root: felt, // hashN(edge_list[0].two_node_hash, ..., edge_list[N-1].two_node_hash)
    edge_list: Edge*,
}

struct Edge {
    parent: Node,
    child: Node,
    two_node_hash: felt, // hash2(parent.node_hash, child.node_hash)
}

struct Node {
    pubkey: felt,
    metadata: Metadata,
    node_hash: felt, // hashN(pubkey, metadata.depth, metadata.width)
}

struct Metadata {
    depth: felt,
    width: felt,
}

struct Block {
    transactions: Transaction*,
    transactions_merkle_root: felt,
    block_sig: felt,
    timestamp: felt,
    root_message: RootMessage*, // length could be zero or one
    signature_r: felt, // recover public key from message and signature.
    signature_s: felt,
    // pubkey: felt,
}

struct RootMessage {
    prev_block_hash: felt,
    timestamp: felt,
    signature_r: felt,
    signature_s: felt,
}

struct Transaction {
    prev_block_hash: felt,
    command: Command,
    // pubkey: felt,
    signature_r: felt, // recover public key from message and signature.
    signature_s: felt,
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

func verify_transaction(state: State, transaction: Transaction) -> (state: State) {
    alloc_locals;
    local new_state: State = state;
    // parse transaction to get command.
    // then parse command get command type and arguments.
    // switch by command type.
    // if COMMAND_CATEGORY_CREATE:
    //    - check that transaction pubkey has authority over target argument by looking up CATEGORY_CATEGORY table.
    //    - check that signature transaction verifies.
    //    - update state according to the command. (add category and re-calculate hashes)
    // if COMMAND_CATEGORY_REMOVE:
    //    - check that transaction pubkey has authority over target argument by looking up CATEGORY_CATEGORY table.
    //    - check that signature transaction verifies.
    //    - update state according to the command. (remove category and re-calculate hashes)
    // if COMMAND_NODE_CREATE:
    //    - check that transaction pubkey has authority over target argument by looking up category_id table.
    //    - check that signature transaction verifies.
    //    - update state according to the command.
    //      - add node in category_id table.
    //      - re-calculate hashes
    // if COMMAND_NODE_REMOVE:
    //    - check that transaction pubkey has authority over target argument by looking up category_id table.
    //    - check that signature transaction verifies.
    //    - update state according to the command.
    //      - mark node in category_id table.
    //      - mark linked child nodes
    //      - remove all marked nodes
    //      - re-calculate hashes
    return new_state;
}

func verify_transaction_recursive(state: State, transactions: Transaction*) -> (state: State) {
    alloc_locals;
    local new_state: State = verify_transaction(state, transactions);
    return verify_transaction_recursive(new_state, transactions + Transaction.SIZE);
}

func verify_block(state:State, block: Block){
    // check block authenticity except for transaction validity.
}

func update_block(state: State, block: Block) -> (state: State) {
    alloc_locals;
    // check if block itself has correct signature, timestamp and block reference.
    // lookup CATEGORY_BLOCK table and if pubkey is correct.
    verify_block(state, block);
    // check contents of block (txs) are correct.
    local new_state: State = verify_transaction_recursive(state, block.transactions);
    return new_state;
}

func update_block_recursive(state: State, blocks: Block*) -> (state: State) {
    alloc_locals;
    local new_state: State = update_block(state, blocks);
    return update_block_recursive(new_state, blocks + Block.SIZE);
}

func main() {
    alloc_locals;
    // given list of block, update state
    local state: State;
    local blocks: Block*;
    local latest_state: State; // latest_state should be hardcoded, also get verified by verifier.
    %{
        # assign state variable from input json. it could be initial state.
        # assign blocks variable from input json
    %}
    tempvar updated_state = update_block_recursive(state, blocks);
    // assert that updated_state and latest_state match!

    return ();
}
