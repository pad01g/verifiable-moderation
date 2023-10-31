from verimod import (
    compute_hash_chain_with_length,
    recompute_child_hash,
    recompute_category_hash_by_reference,
    CATEGORY_CATEGORY,
    recompute_state_hash,
)

from starkware.crypto.signature.signature import (
    pedersen_hash)

def test_compute_hash_chain_with_length():
    h = compute_hash_chain_with_length([0, 1, 2, 3])
    # print(hex(h))
    assert hex(h) == "0x601e94b9063887ec3311c3f85951215d067b6c46cf427be78beb69b369a5fd3"

test_compute_hash_chain_with_length()

def test_recompute_child_hash():
    h = recompute_child_hash([
        {
            "n_category_elements_child": 0,
            "category_elements_child": [],
            "depth": 0,
            "width": 0,
            "pubkey": "0x0",
        }
    ])
    # print(hex(h))
    assert hex(h) == "0x7432f3281ff4bb79d201ad49ed90ed1feaad9032e65e83722b2ce978c481e8f"

test_recompute_child_hash()

def test_hash0_and_hashchain():
    h1 = compute_hash_chain_with_length([0])
    h2 = pedersen_hash(0)
    # print(hex(h1), hex(h2))
    assert h1 != h2

test_hash0_and_hashchain()

def test_recompute_category_hash_by_reference():
    category = {
        "data": {
            "category_elements_child": [
                {
                    "n_category_elements_child": 0,
                    "category_elements_child": [],
                    "depth": 0,
                    "width": 0,
                    "pubkey": "0x0",
                }
            ],
            "n_category_elements_child": 1,
            "category_type": hex(CATEGORY_CATEGORY),
        },
        "hash": "0x431364ed1f517fbacea1491a38376852e05933f3b0f2786e1ca702f08a82c9d"
    }
    recompute_category_hash_by_reference(category)
    # print(category["hash"])
    assert category["hash"] == "0x3f6c71c281f00f1bd4b9fce19dd54e2e4f301c78fd4da7831ccbd261526ac30"

test_recompute_category_hash_by_reference()

def test_recompute_state_hash():
    state = {
        "state": {
            "root_pubkey": "0x1",
            "all_category_hash": 1,
            "n_all_category": 1,
            "all_category": [
                {
                    "data": {
                        "category_elements_child": [
                            {
                                "n_category_elements_child": 0,
                                "category_elements_child": [],
                                "depth": 0,
                                "width": 0,
                                "pubkey": "0x0",
                            }
                        ],
                        "n_category_elements_child": 1,
                        "category_type": hex(CATEGORY_CATEGORY),
                    },
                    "hash": "0x431364ed1f517fbacea1491a38376852e05933f3b0f2786e1ca702f08a82c9d"
                },
            ],
            "block_hash": 1,
        }
    }
    state, all_hash = recompute_state_hash(state)
    print(all_hash)
    assert all_hash == "0x7acc582d0b522d11f37066fad1ed8fbe21dbba2f11653a33813484ce3c7c729"

test_recompute_state_hash()