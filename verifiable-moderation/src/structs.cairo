
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
    root_pubkey: felt,
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
