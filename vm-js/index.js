const assign_category_without_pubkey = () => {}
const search_and_remove_node_from_state_same_level = () => {}
const mark_deleted_node = () => {}

const for_loop_inside = (vars, current) => {

    let new_category_list_index;

    const category_list_current_authorized = (vars.category_list[current].pubkey == vars.auth_pubkey);

    console.log(JSON.stringify({
        pubkey: vars.category_list[current].pubkey,
        authorized: vars.authorized,
        category_list_current_authorized,
        category_list_current_pubkey: vars.category_list[current].pubkey,
        auth_pubkey: vars.auth_pubkey,
    }))


    if (vars.category_list[current].pubkey == vars.pubkey){

        if (vars.authorized){
            // you can safely remove if authorized
            new_category_list_index = vars.new_category_list_index;
            // console.log("found pubkey")
        }else{
            new_category_list_index = vars.new_category_list_index;
            const msg = "permission error. not authorized and found pubkey.";
            // console.log(msg);
            throw new Error(msg)
        }
    }else{

        const authorized = (vars.authorized ? true : category_list_current_authorized)

        const filtered_list = remove_node_from_state_by_reference_recursive_noloop(
            vars.category_list[current].category_list,
            vars.category_list[current].category_list_length,
            vars.pubkey,
            vars.auth_pubkey,
            authorized,
        );

        const new_list = {
            pubkey: vars.category_list[current].pubkey,
            category_list: filtered_list,
        }

        vars.new_category_list[vars.new_category_list_index] = (new_list);
        new_category_list_index = vars.new_category_list_index + 1;
    }

    const new_vars = {
        new_category_list: vars.new_category_list,
        new_category_list_index: new_category_list_index,
        category_list: vars.category_list,
        pubkey: vars.pubkey,
        auth_pubkey: vars.auth_pubkey,
        authorized: vars.authorized,
    }
    return new_vars;
}

const for_loop = (vars, max, current) => {
    if (max <= current) {
        return vars;
    }
    const new_vars = for_loop_inside(vars, current);
    return for_loop(new_vars, max, current + 1);
}

const remove_node_from_state_by_reference_recursive_noloop = (
    category_list,
    category_list_length,
    pubkey,
    auth_pubkey,
    authorized,
) => {
    const new_category_list = [];
    const new_category_list_index = 0;
    const vars = {
        new_category_list,
        new_category_list_index,
        category_list,
        pubkey,
        auth_pubkey,
        authorized,
    }
    const new_vars = for_loop(vars, category_list_length, 0);
    return new_vars.new_category_list;
}

const verify_transaction_node_remove = (state, transaction, auth_pubkey) => {
    const new_state = { all_category: [] }
    const pubkey = transaction.pubkey;
    const authorized = false;
    const category_list = remove_node_from_state_by_reference_recursive_noloop(
        state.all_category,
        state.all_category_length,
        pubkey,
        auth_pubkey,
        authorized,
    );
    new_state.all_category = category_list
    return new_state;
}

const main = () => {
    const state = {
        all_category_length: 1,
        all_category: [
            {
                pubkey: 0,
                category_list_length: 2,
                category_list: [
                    {
                        pubkey: 1,
                        category_list_length: 0,
                        category_list: [],
                    },
                    {
                        pubkey: 2,
                        category_list_length: 3,
                        category_list: [
                            {
                                pubkey: 789,
                                category_list_length: 1,
                                category_list: [
                                    {
                                        pubkey: 5,
                                        category_list_length: 0,
                                        category_list: []
                                    },
                                ]
                            },
                            {
                                pubkey: 123,
                                category_list_length: 1,
                                category_list: [
                                    {
                                        pubkey: 3,
                                        category_list_length: 0,
                                        category_list: []
                                    },
                                ]
                            },
                            {
                                pubkey: 456,
                                category_list_length: 1,
                                category_list: [
                                    {
                                        pubkey: 4,
                                        category_list_length: 0,
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
    const auth_pubkey = 2;

    const result = verify_transaction_node_remove(state, transaction, auth_pubkey);
    console.log(JSON.stringify({result, state}, null, 2));
}

main();