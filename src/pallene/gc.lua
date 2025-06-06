-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local ir = require "pallene.ir"
local flow = require "pallene.flow"
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

local function cmd_uses_gc(cmd)
    local tag = cmd._tag
    assert(tagged_union.typename(tag) == "ir.Cmd")
    return tag == "ir.Cmd.CallStatic" or
           tag == "ir.Cmd.CallDyn" or
           tag == "ir.Cmd.CheckGC"
end

-- Returns information that is used for allocating variables into the Lua stack.
-- The returned data is:
--      * live_gc_vars:
--          for each command, has a list of GC'd variables that are alive during that command.
--      * live_at_same_time:
--          for each GC'd variable, indicates what other GC'd variables are alive at the same time,
--          that is, if both are alive during the same command for some command in the function.
--      * max_frame_size:
--          what's the maximum number of slots of the Lua stack used for storing GC'd variables
--          during the function.
local function compute_stack_slots(func)

    -- 1) Find live GC'd variables for each basic block
    local function init_start(start_set, block_index)
        -- set returned variables to "live" on exit block
        if block_index == #func.blocks then
            for _, var in ipairs(func.ret_vars) do
                start_set[var] = true
            end
        end
    end

    local function compute_gen_kill(block_i, cmd_i)
        local cmd = func.blocks[block_i].cmds[cmd_i]
        assert(tagged_union.typename(cmd._tag) == "ir.Cmd")
        local gk = flow.GenKill()
        for _, dst in ipairs(ir.get_dsts(cmd)) do
            local typ = func.vars[dst].typ
            if types.is_gc(typ) then
                flow.kill_value(gk, dst)
            end
        end

        for _, src in ipairs(ir.get_srcs(cmd)) do
            if src._tag == "ir.Value.LocalVar" then
                local typ = func.vars[src.id].typ
                if types.is_gc(typ) then
                    flow.gen_value(gk, src.id)
                end
            end
        end
        return gk
    end

    local flow_info = flow.FlowInfo(
        flow.Order.Backwards, compute_gen_kill, init_start)
    local sets_list = flow.flow_analysis(func.blocks, flow_info)

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
        local lives_block = sets_list[block_i]
        for cmd_i = #block.cmds, 1, -1 do
            local cmd = block.cmds[cmd_i]
            flow.update_set(lives_block, flow_info, block_i, cmd_i)
            if cmd_uses_gc(cmd) then
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

    return live_gc_vars, max_frame_size, slot_of_variable
end

local function Definition(block_i, cmd_i, var_i)
    return {
        block_i = block_i,
        cmd_i   = cmd_i,
        var_i   = var_i,
    }
end

local function make_definition_list(func)
    local def_list = {}  -- { Definition }
    local cmd_def_map  = {}  -- { block_id => { cmd_id => {definition_id} } }
    local var_def_map  = {}  -- { var_id => {definition_id}? }
    for var_i, var in ipairs(func.vars) do
        if types.is_gc(var.typ) then
            var_def_map[var_i] = {}
        else
            var_def_map[var_i] = false
        end
    end
    for block_i, block in ipairs(func.blocks) do
        local block_map = {}
        cmd_def_map[block_i] = block_map
        for cmd_i, cmd in ipairs(block.cmds) do
            local cmd_map = {}
            block_map[cmd_i] = cmd_map
            for _, dst in ipairs(ir.get_dsts(cmd)) do
                local typ = func.vars[dst].typ
                if types.is_gc(typ) then
                    local def = Definition(block_i,cmd_i,dst)
                    table.insert(def_list, def)
                    local def_id = #def_list
                    table.insert(cmd_map, def_id)

                    local var_defs = var_def_map[dst]
                    table.insert(var_defs, def_id)
                end
            end
        end
    end
    return def_list, cmd_def_map, var_def_map
end

local function compute_vars_to_mirror(func)

    -- 1) Register definitions of GC'd variables
    local def_list, cmd_def_map, var_def_map = make_definition_list(func)

    -- 2) Find reaching definitions for each basic block
    local function init_start(_start_set, _block_index)
    end

    local function compute_gen_kill(block_i, cmd_i)
        local cmd = func.blocks[block_i].cmds[cmd_i]
        local gk = flow.GenKill()
        for _, dst in ipairs(ir.get_dsts(cmd)) do
            local typ = func.vars[dst].typ
            if types.is_gc(typ) then
                local var_defs = var_def_map[dst]
                for _, def_id in ipairs(var_defs) do
                    flow.kill_value(gk, def_id)
                end
            end
        end
        local current_defs = cmd_def_map[block_i][cmd_i]
        if current_defs then
            for _, def in ipairs(current_defs) do
                flow.gen_value(gk, def)
            end
        end
        return gk
    end

    local flow_info = flow.FlowInfo(
        flow.Order.Forward, compute_gen_kill, init_start)
    local sets_list = flow.flow_analysis(func.blocks, flow_info)

    -- 3) Find which definitions reach commands that might call the GC, that is, which definitions
    -- writes have to be mirroed to the stack
    local vars_to_mirror = {}  -- { block_id => { cmd_id => set of var_i } }
    for block_i, block in ipairs(func.blocks) do
        local block_defs = {}
        vars_to_mirror[block_i] = block_defs
        for cmd_i = 1, #block.cmds do
            block_defs[cmd_i] = {}
        end
    end
    for block_i, block in ipairs(func.blocks) do
        local defs_block = sets_list[block_i]
        for cmd_i, cmd in ipairs(block.cmds) do
            flow.update_set(defs_block, flow_info, block_i, cmd_i)
            if cmd_uses_gc(cmd) then
                for def_i, _ in pairs(defs_block) do
                    local def = def_list[def_i]
                    vars_to_mirror[def.block_i][def.cmd_i][def.var_i] = true
                end
            end
        end
    end

    return vars_to_mirror
end

function gc.compute_gc_info(func)
    local live_gc_vars, max_frame_size, slot_of_variable = compute_stack_slots(func)
    local vars_to_mirror = compute_vars_to_mirror(func)
    return {
        live_gc_vars = live_gc_vars,
        max_frame_size = max_frame_size,
        slot_of_variable = slot_of_variable,
        vars_to_mirror = vars_to_mirror,
    }
end

return gc
