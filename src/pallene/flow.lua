-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- Functions for doing flow analysis
--
-- The flow.lua file is designed as an API that helps doing flow analysis.
--
-- Flow Analysis introduction
--
-- We give a brief introduction of flow analysis just to get the reader acquainted with the
-- terminology being used here. To better understand the code you should know how flow analys work
-- already.
--
-- Doing flow analysis on a function consists of tracking down properties of it's code along each
-- command. These properties are represented using a set. Each basic block has a "start" set and a
-- "finish" set. The "start" set is the set of values available right before we start to process the
-- block's commands and the "finish" set is the set of values available right after we finish
-- processing the block's commands. Each block also has a "kill" and a "gen" set that help transform
-- the "start" set into the "finish" set. The "kill" set contains the values that will be removed
-- from the running set while "gen" (as in "generate") contains the values that will be added to it.
-- The flow analysis algorithm's input is a collection of "kill" and "gen" sets for each block and
-- the initial values for the "start" sets of each block. During it's runtime, the algorithm updates
-- the "start" and "finish" sets in a loop until they all converge to some value. The algorithm
-- requires a loop because a block's "start" set depends on the "finish" set of it's predecessors or
-- it's successors, depending on what order the flow analysis is being done (some analyses require
-- that we walk through the code backwards).
--
-- API usage:
--
-- When doing flow analysis, follow these steps. Also look at examples of usage inside the codebase,
-- as in "gc.lua".
--
--
-- 1) Create a FlowInfo object and the functions it receives as arguments (see the flow.FlowInfo
-- constructor to learn what those functions are supposed to do).
--
--
-- 2) Call the function "flow.flow_analysis" using as arguments the blocks of the functions you're
-- analysing and the "FlowInfo" object you created in step 3. "flow.flow_analysis" returns a list
-- that contains a set for each block in the function. The returned sets are the starting sets of
-- each corresponding block. To get the sets corresponding to the commands of a block, you'll have
-- to loop through them and update the set yourself. The next step teaches you how to do that.
--
--
-- 3) Having now the list of sets, iterate through blocks and commands (if you used Order.Backwards
-- previously, in step 3, then you'll have to iterate through the commands of the block backwards
-- too).
--
--     3.1) Inside the loop that iterates over a block's commands, call "flow.update_set" to update
--     the set.


local flow = {}

local ir = require "pallene.ir"
local tagged_union = require "pallene.tagged_union"
local define_union = tagged_union.in_namespace(flow, "flow")

define_union("Order", {
    Forward   = {},
    Backwards = {},
})

function flow.GenKill()
    return {
        kill = {},  -- set of values
        gen  = {},  -- set of values
    }
end


local function FlowState()
    return {
        start  = {},   -- set of values when we start analysing the block
        finish = {},   -- set of values when we finish analysing the block,
        gk     = flow.GenKill(),
    }
end

function flow.FlowInfo(order, compute_gen_kill, init_start)
    return {
        -- "order" is the order in which commands and blocks are iterated during flow analysis.
        -- "Order.Forwards" updates the running set by reading a block's commands in order and
        -- builds the "start" set of a block from it's predecessors' "finish" sets, while
        -- "Order.Backwards" updates the running set by reading a block's commands in backwards
        -- order and builds the "start" set of a block from it's successors' "finish" sets.
        order = order,  -- flow.Order

        -- "compute_gen_kill" is a function that will be used for updating the running set as we
        -- read commands. The first argument is the block index and the second is the command's
        -- index inside the block. For indicating which elements should be inserted/removed
        -- into/from the set, create a new flow.GenKill object and then call the API functions
        -- "flow.kill_value" for removal and "flow.gen_value" for insertion. The "compute_gen_kill"
        --  function must return the flow.GenKill object that you created.
        compute_gen_kill = compute_gen_kill,  -- (block_id, cmd_id) -> flow.GenKill

        -- "init_start" is a function that will be used for initializing the "start" sets. The
        -- function is called once for each basic block. It's first argument is the "start" set of
        -- the block and the second is the block's index.
        init_start = init_start,  -- function  (set, block_id) -> void
    }
end

local function apply_gen_kill_sets(flow_state)
    local start = flow_state.start
    local finish = flow_state.finish
    local gen = flow_state.gk.gen
    local kill = flow_state.gk.kill
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

local function merge_sets(state_list, src_indices, dest_index)
    local dest = state_list[dest_index].start
    clear_set(dest)
    for _,src_i in ipairs(src_indices) do
        local src = state_list[src_i].finish
        for v, _ in pairs(src) do
            dest[v] = true
        end
    end
end

local function apply_cmd_gk_to_block_gk(cmd_gk, block_gk)
    local cmd_gen = cmd_gk.gen
    local cmd_kill = cmd_gk.kill
    local block_gen = block_gk.gen
    local block_kill = block_gk.kill
    for v,_ in pairs(cmd_gen) do
        assert(not cmd_kill[v], "cmd_gen and cmd_kill must not intersect")
        block_gen[v] = true
        block_kill[v] = nil
    end
    for v,_ in pairs(cmd_kill) do
        assert(not cmd_gen[v], "cmd_gen and cmd_kill must not intersect")
        block_gen[v] = nil
        block_kill[v] = true
    end
end

local function make_state_list(block_list, flow_info)
    local state_list = {}
    local order = flow_info.order._tag
    for block_i, block in ipairs(block_list) do
        local block_state = FlowState()
        state_list[block_i] = block_state
        flow_info.init_start(block_state.start, block_i)
        if order == "flow.Order.Forward" then
            for cmd_i = 1, #block.cmds do
                local cmd_gk = flow_info.compute_gen_kill(block_i, cmd_i)
                apply_cmd_gk_to_block_gk(cmd_gk, block_state.gk)
            end
        elseif order == "flow.Order.Backwards" then
            for cmd_i = #block.cmds, 1, -1  do
                local cmd_gk = flow_info.compute_gen_kill(block_i, cmd_i)
                apply_cmd_gk_to_block_gk(cmd_gk, block_state.gk)
            end
        else
            tagged_union.error(order)
        end
    end
    return state_list
end

function flow.flow_analysis(block_list, flow_info)
                               -- ({ir.BasicBlock}, flow.FlowInfo) -> { block_id -> set }
    local state_list = make_state_list(block_list, flow_info)

    local succ_list = ir.get_successor_list(block_list)
    local pred_list = ir.get_predecessor_list(block_list)

    local block_order
    local merge_src_list
    local dirty_propagation_list
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
        local state = state_list[block_i]

        -- first block's starting set is supposed to be constant
        if block_i ~= first_block_i then
            local src_indices = merge_src_list[block_i]
            merge_sets(state_list, src_indices, block_i)
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

    local block_start_list = {}
    for state_i, flow_state in ipairs(state_list) do
        block_start_list[state_i] = flow_state.start
    end

    return block_start_list
end

function flow.update_set(set, flow_info, block_i, cmd_i) -- (set, flow.FlowInfo, block_id) -> void
    local gk = flow_info.compute_gen_kill(block_i, cmd_i)
    for v,_ in pairs(gk.gen) do
        assert(not gk.kill[v], "gen and kill must not intersect")
        set[v] = true
    end
    for v,_ in pairs(gk.kill) do
        assert(not gk.gen[v], "gen and kill must not intersect")
        set[v] = nil
    end
end

function flow.gen_value(gen_kill, v) -- (flow.GenKill, element) -> void
    gen_kill.gen[v] = true
    gen_kill.kill[v] = nil
end

function flow.kill_value(gen_kill, v) -- (flow.GenKill, element) -> void
    gen_kill.gen[v] = nil
    gen_kill.kill[v] = true
end

return flow
