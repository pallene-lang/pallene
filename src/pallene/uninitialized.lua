-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- In this module we detect when variables are used before being initialized and when control flows
-- to the end of a non-void function without returning. The analysis is fundamentally a dataflow
-- one, but we don't check for convergence (this set of properties seem to converge in one pass) and
-- we don't merge the properties of one basic block with one that it jumps to if the "jumped to"
-- block has a lower id, that is, we don't consider backwards jumps (that's how we deal with loops
-- for now).  Make sure that you call ir.clean first, so that it does the right thing in the
-- presence of `while true` loops.
--
-- `uninit` is the set of variables that are potentially uninitialized.
-- `kill` is the set of variables that are initialized at a given block.

local ir = require "pallene.ir"
local tagged_union = require "pallene.tagged_union"

local uninitialized = {}

local function fill_set(cmd, set, val)
    assert(tagged_union.typename(cmd._tag) == "ir.Cmd")
    for _, src in ipairs(ir.get_srcs(cmd)) do
        if src._tag == "ir.Value.LocalVar" then
            -- `SetField` instructions can count as initializers when the target is an
            -- upvalue box. This is because upvalue boxes are allocated, but not initialized
            -- upon declaration.
            if cmd._tag == "ir.Cmd.SetField" and cmd.rec_typ.is_upvalue_box then
                set[src.id] = val
            end
        end
    end

    -- Artificial initializers introduced by the compilers do not count.
    if not (cmd._tag == "ir.Cmd.NewRecord" and cmd.rec_typ.is_upvalue_box) then
        for _, v_id in ipairs(ir.get_dsts(cmd)) do
            set[v_id] = val
        end
    end
end

local function flow_analysis(block_list, uninit_sets, kill_sets)
    local function merge_uninit(A, B, kill)
        local changed = false
        for v, _ in pairs(B) do
            if not kill[v] then
                if not A[v] then
                    changed = true
                end
                A[v] = true
            end
        end
        return changed
    end

    local block_order = ir.get_depth_search_topological_sort(block_list)

    local function block_analysis(block_i)
        local block = block_list[block_i]
        local uninit = uninit_sets[block_i]
        local kill = kill_sets[block_i]
        local changed = false
        if block.next  then
            local c = merge_uninit(uninit_sets[block.next], uninit, kill)
            changed = c or changed
        end
        if block.jmp_false  then
            local c = merge_uninit(uninit_sets[block.jmp_false.target], uninit, kill)
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

local function check_uninit(block, input_uninit)
    for _,cmd in ipairs(block.cmds) do
        fill_set(cmd, input_uninit, nil)
        for _, src in ipairs(ir.get_srcs(cmd)) do
            if src._tag == "ir.Value.LocalVar" and input_uninit[src.id] then
                coroutine.yield({v = src.id, loc = cmd.loc})
            end
        end
    end
end

local function gen_kill_set(block)
    local kill = {}
    for _,cmd in ipairs(block.cmds) do
        fill_set(cmd, kill, true)
    end
    return kill
end

function uninitialized.verify_variables(module)

    local errors = {}

    for _, func in ipairs(module.functions) do

        local nvars = #func.vars
        local nargs = #func.typ.arg_types

        -- initialize sets
        local kill_sets = {}
        local uninit_sets = {}
        for _,b in ipairs(func.blocks) do
            local kill = gen_kill_set(b)
            table.insert(kill_sets, kill)
            table.insert(uninit_sets, {})
        end
        local entry_uninit = uninit_sets[1]
        for v_i = nargs+1, nvars do
            entry_uninit[v_i] = true
        end

        -- solve flow equations
        flow_analysis(func.blocks, uninit_sets, kill_sets)

        -- check for errors
        local check = coroutine.wrap(function()
            for i,b in ipairs(func.blocks) do
                local uninit = uninit_sets[i]
                check_uninit(b, uninit)
            end
        end)

        local reported_variables = {} -- (only one error message per variable)
        for o in check do
            local v, loc = o.v, o.loc
            if not reported_variables[v] then
                reported_variables[v] = true
                local name = assert(func.vars[v].name)
                table.insert(errors, loc:format_error(
                        "error: variable '%s' is used before being initialized", name))
            end
        end

        local exit_uninit = uninit_sets[#func.blocks]
        if #func.ret_vars > 0 then
            local ret1 = func.ret_vars[1]
            if exit_uninit[ret1] then
                assert(func.loc)
                table.insert(errors, func.loc:format_error(
                    "control reaches end of function with non-empty return type"))
            end
        end
    end

    if #errors == 0 then
        return module, {}
    else
        return false, errors
    end
end

return uninitialized


