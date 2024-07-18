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

local function flow_analysis(block_list, live_sets, gen_sets, kill_sets)
    local function merge_live(A, B, gen_set, kill_set)
        local changed = false
        for v, _ in pairs(B) do
            local val = true
            if kill_set[v] then
                val = nil
            end
            local previous_val = A[v]
            local new_val = previous_val or val
            A[v] = new_val
            changed = changed or (previous_val ~= new_val)
        end
        for v, gen in pairs(gen_set) do
            assert(gen ~= true or gen ~= kill_set[v], "gen and kill can't both be true")
            local previous_val = A[v]
            local new_val = true
            A[v] = new_val
            changed = changed or (previous_val ~= new_val)
        end
        return changed
    end

    local pred_list = ir.get_predecessor_list(block_list)
    local block_order = ir.get_predecessor_depth_search_topological_sort(pred_list)

    local function block_analysis(block_i)
        local block_preds = pred_list[block_i]
        local live = live_sets[block_i]
        local gen  = gen_sets[block_i]
        local kill = kill_sets[block_i]
        local changed = false
        for _,pred in ipairs(block_preds) do
            local c = merge_live(live_sets[pred], live, gen, kill)
            changed = c or changed
        end
        return changed
    end

    repeat
        local changed = false
        for _,block_i in ipairs(block_order) do
            changed = block_analysis(block_i) or changed
        end
    until not changed
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

local function make_gen_kill_sets(block)
    local gen = {}
    local kill = {}
    for i = #block.cmds, 1, -1 do
        local cmd = block.cmds[i]
        mark_gen_kill(cmd, gen, kill)
    end
    return gen, kill
end

function gc.compute_stack_slots(func)
    -- initialize sets

    -- variables with values that turn live in a given block w.r.t flow entering the block
    local gen_sets =  {} -- { block_id -> { var_id -> bool? } }

    -- variables with values that are killed in a given block w.r.t flow entering the block
    local kill_sets = {} -- { block_id -> { var_id -> bool? } }

    -- variables with values that are live at the end of a given block
    local live_sets = {} -- { block_id -> { var_id -> bool? } }

    for _,b in ipairs(func.blocks) do
        local gen, kill = make_gen_kill_sets(b)
        table.insert(kill_sets, kill)
        table.insert(gen_sets, gen)
        table.insert(live_sets, {})
    end

    -- set returned variables to "live" on exit block
    if #func.blocks > 0 then
        local exit_live_set = live_sets[#func.blocks]
        for _, var in ipairs(func.ret_vars) do
            exit_live_set[var] = true
        end
    end

    -- 1) Find live variables at the end of each basic block
    flow_analysis(func.blocks, live_sets, gen_sets, kill_sets)

    -- 2) Find which GC'd variables are live at each GC spot in the program and
    --    which  GC'd variables are live at the same time
    local live_gc_vars = {} -- { cmd => {var_id}? }
    local live_at_same_time = {} -- { var_id => { var_id => bool? }? }

    for block_i, block in ipairs(func.blocks) do
        local lives_block = live_sets[block_i]
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

            local tag = cmd._tag
            if  tag == "ir.Cmd.CallStatic" or
                tag == "ir.Cmd.CallDyn" or
                tag == "ir.Cmd.CheckGC"
            then
                local lives_cmd = {}
                for var,_ in pairs(lives_block) do
                    table.insert(lives_cmd, var)
                end
                live_gc_vars[cmd] = lives_cmd
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
