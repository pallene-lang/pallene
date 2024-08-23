-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- Functions for doing flow analysis
--
-- The flow.lua file is designed as an API that helps doing flow analysis.
--
-- We give a brief introduction of flow analysis just to get the reader acquainted with the
-- terminology being used here. To better understand the code you should know how flow analys work
-- already.
--
-- Flow Analysis introduction:
--
-- Doing flow analysis on a function consists of tracking down properties of it's code along each
-- command. These properties are represented using a set. Each basic block has a "start" set and a
-- "finish" set. The "start" set is the set of values available right before we start to process the
-- block's commands and the "finish" set is the set of values available right after we finish
-- processing the commands. Each block also has a "kill" and a "gen" set that help transform the
-- "start" set into the "finish" set. The "kill" set contains the values that will be removed from
-- the running set while "gen" (as in "generate") contains the values that will be added to it. The
-- flow analysis algorithm's input is a pair of "kill" and "gen" sets for each block and the initial
-- values for the "start" sets of each block. During it's runtime, the algorithm updates the "start"
-- and "finish" sets in a loop until they all converge to some value. The algorithm requires a loop
-- because a block's "start" set depends on the "finish" set of it's predecessor or it's successors,
-- depending on what order the flow analysis is being done (some analyses require that we walk
-- through the code backwards).
--
--
-- API usage:
--
-- When doing flow analysis, follow these steps. Also look at examples of usage inside the codebase,
-- as in "gc.lua".
--
--  1) Create a function of type "function (set, block id)" that will be used internally by the API
--  to initialize the "start" sets. The function is called once for each basic block. It's first
--  argument is the "start" set of the block and the second is the block's index.
--
--  2) Create function of type "function (FlowState, block id, command id)" that will be used for
--  updating the running set as we read the function's commands. The first argument is an object
--  of type FlowState, that stores various sets used internally; the second argument is the
--  block index and the third is the command's index inside the block. For removing/adding
--  elements from/to the set, use the API function "flow.kill_value" for removal
--  and "flow.gen_value" for insertion. Both functions are of type "function (FlowState,
--  element)", where the first argument is a FlowState object and the second is the element
--  that will be removed/inserted from/into the set.
--
--  3) Create a FlowInfo object
--      The object's constructor takes three parameters:
--          order:
--              The order in which commands and blocks are iterated during flow analysis.
--              "Order.Forwards" updates the running set by reading a block's commands in order and
--              builds the "start" set of a block from it's predecessors' "finish" sets, while
--              "Order.Backwards" updates the running set by reading a block's commands in backwards
--              order and builds the "start" set of a block from it's successors' "finish" sets.
--          process_cmd:
--              function used to update the running set, use the one you wrote in step 2
--          init_start:
--              function used to initalize the "start" set of blocks, use the one you wrote in
--              step 1
--
--  4) Call the function "flow.flow_analysis". It's parameters are:
--      func_block:
--          A list of the function's blocks
--      flow_info :
--          An object of type "FlowInfo". Use the one you created in step 3.
--
--  "flow.flow_analysis" returns a list of objects of type "FlowState.Build". Each basic block has a
--  corresponding object on the list.
--
--  5) Having now the list of flow states, iterate through blocks and commands (if you used
--  Order.Backwards previously, in step 3, then you'll have to iterate through the commands of the
--  block backwards too).
--
--    5.1) Inside the loop that iterates over blocks and before entering the loop that iterates over
--    the commands of a block, call "flow.make_apply_state". The function receives one argument,
--    which will be the flow state of the current block that can retrieved from the list obtained in
--    step 4 (e.g. the flow state corresponding to the 3rd block will be flow_state_list[3]).
--    "flow.make_apply_state" returns an object of type "FlowState.Apply". This one will be used to
--    update the state of the flow analysis set as we iterate over the commands of the current
--    block. This set can be accesses through the "set" property of the "FlowState.Apply" object
--    returned by "flow.make_apply_state". Checking the contents of this set as you update it
--    throught the commands is essentialy the whole point of everything we're doing here, that's
--    what flow analysis is for. The "set" property of the "FlowState.Apply" object returned by
--    "flow.make_apply_state" is equal the "start" set of the current block.
--
--    5.2) Inside the loop that iterates over a block's commands, call "flow.update_set" to update
--    the set of the "FlowState.Apply" object. "flow.update_set"'s first argument is the
--    "FlowState.Apply" object; second argument is the FlowInfo object created in step 3; third
--    argument is the current block's index and the forth argument is the current command's index
--    inside the block.

local flow = {}

local ir = require "pallene.ir"
local tagged_union = require "pallene.tagged_union"
local define_union = tagged_union.in_namespace(flow, "flow")

define_union("Order", {
    Forward   = {},
    Backwards = {},
})

define_union("FlowState", {
    Build = {
        "start",   -- set of values when we start analysing the block
        "finish",  -- set of values when we finish analysing the block,
        "kill",    -- set of values
        "gen",     -- set of values
    },

    Apply = {
        "set",     -- set of values
    },
})

function flow.FlowInfo(order, process_cmd, init_start)
    return {
        order = order,              -- flow.Order
        process_cmd = process_cmd,  -- function
        init_start = init_start,    -- function
    }
end

local function copy_set(S)
    local new_set = {}
    for v,_ in pairs(S) do
        new_set[v] = true
    end
    return new_set
end

local function apply_gen_kill_sets(flow_state)
    local start = flow_state.start
    local finish = flow_state.finish
    local gen = flow_state.gen
    local kill = flow_state.kill
    local in_changed = false

    for v, _ in pairs(start) do
        local val = true
        if kill[v] then
            val = nil
        end
        local previous_val = finish[v]
        local new_val = previous_val or val
        finish[v] = new_val
        in_changed = in_changed or (previous_val ~= new_val)
    end

    for v, g in pairs(gen) do
        assert(not (g and kill[v]), "gen and kill can't both be true")
        local previous_val = finish[v]
        local new_val = true
        finish[v] = new_val
        in_changed = in_changed or (previous_val ~= new_val)
    end

    for v, _ in pairs(finish) do
        if not start[v] and not gen[v] then
            finish[v] = nil
            in_changed = true
        end
    end

    return in_changed
end

local function clear_set(S)
    for v,_ in pairs(S) do
        S[v] = nil
    end
end

local function merge_sets(blocks_states, src_indices, dest_index)
    local dest = blocks_states[dest_index].start
    clear_set(dest)
    for _,src_i in ipairs(src_indices) do
        local src = blocks_states[src_i].finish
        for v, _ in pairs(src) do
            dest[v] = true
        end
    end
end

local function make_state_list(block_list, flow_info)
    local blocks_states = {}
    local order = flow_info.order._tag
    for block_i, block in ipairs(block_list) do
        local state = flow.FlowState.Build({},{},{},{})
        blocks_states[block_i] = state
        flow_info.init_start(state.start, block_i)
        if order == "flow.Order.Forward" then
            for cmd_i = 1, #block.cmds do
                flow_info.process_cmd(state, block_i, cmd_i)
            end
        elseif order == "flow.Order.Backwards" then
            for cmd_i = #block.cmds, 1, -1  do
                flow_info.process_cmd(state, block_i, cmd_i)
            end
        else
            tagged_union.error(order)
        end
    end
    return blocks_states
end

function flow.flow_analysis(block_list, flow_info)

    local blocks_states = make_state_list(block_list, flow_info)

    local succ_list = ir.get_successor_list(block_list)
    local pred_list = ir.get_predecessor_list(block_list)

    local block_order    -- { block_id }, order in which blocks will be traversed
    local merge_src_list -- { block_id => { block_id } }, maps a block to the blocks it uses
                         -- for assembling it's "start" set
    local dirty_propagation_list  -- { block_id => { block_id } }, maps a block to the blocks it
                                  -- should propagate the dirty flag when it's "finish" set is
                                  -- changed
    local order = flow_info.order._tag
    if order == "flow.Order.Forward"  then
        block_order = ir.get_successor_depth_search_topological_sort(succ_list)
        merge_src_list = pred_list
        dirty_propagation_list = succ_list
    elseif order == "flow.Order.Backwards" then
        block_order = ir.get_predecessor_depth_search_topological_sort(pred_list)
        merge_src_list = succ_list
        dirty_propagation_list = pred_list
    else
        tagged_union.error(order)
    end

    local dirty_flag = {} -- { block_id -> bool } keeps track of modified blocks
    for i = 1, #block_list do
        dirty_flag[i] = true
    end

    local first_block_i = block_order[1]

    local function update_block(block_i)
        local state = blocks_states[block_i]

        -- first block's starting set is supposed to be constant
        if block_i ~= first_block_i then
            local src_indices = merge_src_list[block_i]
            merge_sets(blocks_states, src_indices, block_i)
        end

        local dirty_propagation = dirty_propagation_list[block_i]
        local state_changed = apply_gen_kill_sets(state)
        if state_changed then
            for _, i in ipairs(dirty_propagation) do
                dirty_flag[i] = true
            end
        end
    end

    repeat
        local found_dirty_block = false
        for _,block_i in ipairs(block_order) do
            if dirty_flag[block_i] then
                found_dirty_block = true
                -- CAREFUL: we have to clean the dirty flag BEFORE updating the block or else a
                -- block that jumps to itself might set it's dirty flag to "true" during
                -- "update_block" and we'll then wrongly set it to "false" in here.
                dirty_flag[block_i] = false
                update_block(block_i)
            end
        end
    until not found_dirty_block

    return blocks_states
end

function flow.kill_value(flow_state, value)
    local tag = flow_state._tag
    if tag == "flow.FlowState.Build" then
        flow_state.kill[value] = true
        flow_state.gen[value] = nil
    elseif tag == "flow.FlowState.Apply" then
        flow_state.set[value] = nil
    else
        tagged_union.error(tag)
    end
end

function flow.gen_value(flow_state, value)
    local tag = flow_state._tag
    if tag == "flow.FlowState.Build" then
        flow_state.gen[value] = true
        flow_state.kill[value] = nil
    elseif tag == "flow.FlowState.Apply" then
        flow_state.set[value] = true
    else
        tagged_union.error(tag)
    end
end

function flow.make_apply_state(flow_state)
    assert(flow_state._tag == "flow.FlowState.Build")
    local start = copy_set(flow_state.start)
    local a_state = flow.FlowState.Apply(start)
    return a_state
end

function flow.update_set(flow_state, flow_info, block_i, cmd_i)
    assert(flow_state._tag == "flow.FlowState.Apply")
    flow_info.process_cmd(flow_state, block_i, cmd_i)
end

return flow
