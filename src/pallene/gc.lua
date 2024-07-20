-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local ir = require "pallene.ir"
local types = require "pallene.types"
local tagged_union = require "pallene.tagged_union"

-- GARBAGE COLLECTION
-- ==================
-- For proper garbage collection in Pallene we must ensure that at every potential garbage
-- collection site all the live GC values must be saved to the the Lua stack, where the GC can see
-- them. The way that we do this is that whenever we assign to a local variable that has a GC type
-- we also assign the same value to the Lua stack.
--
-- Potential garbage collection points are explicit ir.CheckGC nodes and function calls. Per the
-- Pallene calling convention, functions can assume that the initial values of function parameters
-- have already been saved by the caller.
--
-- As an optimization, we don't save values to the Lua stack if the associated variable dies before
-- it reaches a potential garbage collection site. The current implementation uses flow analysis to
-- find live variables. So we don't forget, I'm listing here some ideas to improve the analysis ...
-- But it should be said that we don't know if implementing them would be worth the trouble.
--
--   1) Insert fewer checkGC calls in our functions, or move the checkGC calls to places with fewer
--      live variables. (For example, the end of the scope)
--
--   2) Identify functions that don't call the GC (directly or indirectly) and don't treat calls to
--      them as potential GC sites. (Function inlining might mitigate this for small functions)
--
--   3) Use SSA form or some form of reaching definitions analysis so that we we only need to mirror
--      the writes that reach a GC site, instead of always mirroring all writes to a variable if one
--      of them reaches a GC site.

local gc = {}

local function FlowState()
    return {
        input  = {},  -- {var_id -> bool?} live variables at block start
        output = {},  -- {var_id -> bool?} live variables at block end
        kill   = {},  -- {var_id -> bool?} variables that are killed inside block
        gen    = {},  -- {var_id -> bool?} variables that become live inside block
    }
end

function gc.cmd_uses_gc(tag)
    assert(tagged_union.typename(tag) == "ir.Cmd")
    return tag == "ir.Cmd.CallStatic" or
           tag == "ir.Cmd.CallDyn" or
           tag == "ir.Cmd.CheckGC"
end

local function copy_set(S)
    local new_set = {}
    for v,_ in pairs(S) do
        new_set[v] = true
    end
    return new_set
end

local function flow_analysis(block_list, state_list)
    local function apply_gen_kill_sets(flow_state)
        local input = flow_state.input
        local output = flow_state.output
        local gen = flow_state.gen
        local kill = flow_state.kill
        local in_changed = false

        for v, _ in pairs(output) do
            local val = true
            if kill[v] then
                val = nil
            end
            local previous_val = input[v]
            local new_val = previous_val or val
            input[v] = new_val
            in_changed = in_changed or (previous_val ~= new_val)
        end

        for v, g in pairs(gen) do
            assert(g ~= true or g ~= kill[v], "gen and kill can't both be true")
            local previous_val = input[v]
            local new_val = true
            input[v] = new_val
            in_changed = in_changed or (previous_val ~= new_val)
        end

        for v, _ in pairs(input) do
            if not output[v] and not gen[v] then
                input[v] = nil
                in_changed = true
            end
        end

        return in_changed
    end

    local function merge_live(input, output)
        for v, _ in pairs(input) do
            output[v] = true
        end
    end

    local function empty_set(S)
        for v,_ in pairs(S) do
            S[v] = nil
        end
    end

    local succ_list = ir.get_successor_list(block_list)
    local pred_list = ir.get_predecessor_list(block_list)
    local block_order = ir.get_predecessor_depth_search_topological_sort(pred_list)

    local dirty_flag = {} -- { block_id -> bool? } keeps track of modified blocks
    for i = 1, #block_list do
        dirty_flag[i] = true
    end

    local function update_block(block_i)
        local block_succs = succ_list[block_i]
        local block_preds = pred_list[block_i]
        local state = state_list[block_i]

        -- last block's output is supposed to be fixed
        if block_i ~= #block_list then
            empty_set(state.output)
            for _,succ in ipairs(block_succs) do
                local succ_in = state_list[succ].input
                merge_live(succ_in, state.output)
            end
        end

        local in_changed = apply_gen_kill_sets(state)
        if in_changed then
            for _, pred in ipairs(block_preds) do
                dirty_flag[pred] = true
            end
        end
    end

    repeat
        local found_dirty_block = false
        for _,block_i in ipairs(block_order) do
            if dirty_flag[block_i] then
                found_dirty_block = true
                -- CAREFUL: we have to clean the dirty flag BEFORE updating the block or else we
                -- will do the wrong thing for auto-referencing blocks
                dirty_flag[block_i] = nil
                update_block(block_i)
            end
        end
    until not found_dirty_block
end

local function mark_gen_kill(cmd, gen_set, kill_set)
    assert(tagged_union.typename(cmd._tag) == "ir.Cmd")
    for _, dst in ipairs(ir.get_dsts(cmd)) do
        gen_set[dst] = nil
        kill_set[dst] = true
    end

    for _, src in ipairs(ir.get_srcs(cmd)) do
        if src._tag == "ir.Value.LocalVar" then
            gen_set[src.id] = true
            kill_set[src.id] = nil
        end
    end
end

local function make_gen_kill_sets(block, flow_state)
    for i = #block.cmds, 1, -1 do
        local cmd = block.cmds[i]
        mark_gen_kill(cmd, flow_state.gen, flow_state.kill)
    end
end

function gc.compute_stack_slots(func)

    local state_list = {} -- { FlowState }

    -- initialize states
    for block_i, block in ipairs(func.blocks) do
        local fst = FlowState()
        make_gen_kill_sets(block, fst)
        state_list[block_i] = fst
    end

    -- set returned variables to "live" on exit block
    if #func.blocks > 0 then
        local exit_output = state_list[#func.blocks].output
        for _, var in ipairs(func.ret_vars) do
            exit_output[var] = true
        end
    end

    -- 1) Find live variables at the end of each basic block
    flow_analysis(func.blocks, state_list)

    -- 2) Find which GC'd variables are live at each GC spot in the program and
    --    which  GC'd variables are live at the same time
    local live_gc_vars = {} -- { block_id => { cmd_id => {var_id}? } }
    local live_at_same_time = {} -- { var_id => { var_id => bool? }? }

    -- initialize live_gc_vars
    for _, block in ipairs(func.blocks) do
        local live_on_cmds = {}
        for cmd_i = 1, #block.cmds do
            live_on_cmds[cmd_i] = false
        end
        table.insert(live_gc_vars, live_on_cmds)
    end

    for block_i, block in ipairs(func.blocks) do
        local lives_block = copy_set(state_list[block_i].output)
        -- filter out non-GC'd variables from set
        for var_i, _ in pairs(lives_block) do
            local var = func.vars[var_i]
            if not types.is_gc(var.typ) then
                lives_block[var_i] = nil
            end
        end
        for cmd_i = #block.cmds, 1, -1 do
            local cmd = block.cmds[cmd_i]
            assert(tagged_union.typename(cmd._tag) == "ir.Cmd")
            for _, dst in ipairs(ir.get_dsts(cmd)) do
                lives_block[dst] = nil
            end
            for _, src in ipairs(ir.get_srcs(cmd)) do
                if src._tag == "ir.Value.LocalVar" then
                    local typ = func.vars[src.id].typ
                    if types.is_gc(typ) then
                        lives_block[src.id] = true
                    end
                end
            end

            if gc.cmd_uses_gc(cmd._tag)
            then
                local lives_cmd = {}
                for var,_ in pairs(lives_block) do
                    table.insert(lives_cmd, var)
                end
                live_gc_vars[block_i][cmd_i] = lives_cmd
                for var1,_ in pairs(lives_block) do
                    for var2,_ in pairs(lives_block) do
                        if not live_at_same_time[var1] then
                            live_at_same_time[var1] = {}
                        end
                        live_at_same_time[var1][var2] = true
                    end
                end
            end
        end
    end

    -- 3) Allocate variables to Lua stack slots, ensuring that variables with overlapping lifetimes
    -- get different stack slots. IMPORTANT: stack slots are 0-based. The C we generate prefers
    -- that.

    local max_frame_size = 0
    local slot_of_variable = {} -- { var_id => integer? }

    for v_id = 1, #func.vars do
        slot_of_variable[v_id] = false
    end

    for v1, set in pairs(live_at_same_time) do
        local taken_slots = {}  -- { stack_slot => bool? }
        for v2,_ in pairs(set) do
            local v2_slot = slot_of_variable[v2]
            if v2_slot then
                taken_slots[v2_slot] = true
            end
        end
        for slot = 0, #func.vars do
            if not taken_slots[slot] then
                slot_of_variable[v1] = slot
                max_frame_size = math.max(max_frame_size, slot + 1)
                break
            end
        end
        assert(slot_of_variable[v1], "should always find a slot")
    end

    return {
        live_gc_vars = live_gc_vars,
        max_frame_size = max_frame_size,
        slot_of_variable = slot_of_variable,
    }
end


return gc
