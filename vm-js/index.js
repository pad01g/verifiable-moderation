const assign_category_without_pubkey = () => {}
const search_and_remove_node_from_state_same_level = () => {}
const mark_deleted_node = () => {}

const remove_node_from_state_by_reference_recursive = (
    category_list,
    pubkey
) => {
    const new_category_list = [];
    for(let i = 0; i < category_list.length; i++) {
        if (category_list[i].pubkey != pubkey){

            const filtered_list = remove_node_from_state_by_reference_recursive(
                category_list[i].category_list,
                pubkey
            );

            // category_list[i].category_list = filtered_list

            const new_list = {
                pubkey: category_list[i].pubkey,
                category_list: filtered_list,
            }

            new_category_list.push(new_list);
        }else{
            // console.log("found pubkey")
        }

    }
    return new_category_list;
}

const verify_transaction_node_remove = (state, transaction) => {
    const new_state = { all_category: [] }
    const pubkey = transaction.pubkey;
    const category_list = remove_node_from_state_by_reference_recursive(
        state.all_category,
        pubkey
    );
    new_state.all_category = category_list
    return new_state;
}

const main = () => {
    const state = {
        all_category: [
            {
                pubkey: 0,
                category_list: [
                    {
                        pubkey: 1,
                        category_list: []
                    },
                    {
                        pubkey: 2,
                        category_list: [
                            {
                                pubkey: 123,
                                category_list: [
                                    {
                                        pubkey: 3,
                                        category_list: []
                                    },
                                ]
                            },
                            {
                                pubkey: 456,
                                category_list: [
                                    {
                                        pubkey: 4,
                                        category_list: []
                                    },
                                ]
                            }
                        ]
                    }

                ]
            }
        ]
    }
    const transaction = {pubkey: 123};

    const result = verify_transaction_node_remove(state, transaction);
    console.log(JSON.stringify({result, state}, null, 2));
}

main();