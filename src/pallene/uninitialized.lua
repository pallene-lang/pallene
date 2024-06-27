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

local ir = require "pallene.ir"
local tagged_union = require "pallene.tagged_union"

local uninitialized = {}


local function TState() -- Transfer State
    return {
        uninit = {},              -- list of booleans
    }
end

local function copy_state(A)
    local B = TState()
    for v, _ in pairs(A.uninit) do
        B.uninit[v] = true
    end
    return B
end

local function merge_state(A, B)
    for v, _ in pairs(B.uninit) do
        A.uninit[v] = true
    end
end

local function test(cmd, state)
    assert(tagged_union.typename(cmd._tag) == "ir.Cmd")
    for _, val in ipairs(ir.get_srcs(cmd)) do
        if val._tag == "ir.Value.LocalVar" then
            -- `SetField` instructions can count as initializers when the target is an
            -- upvalue box. This is because upvalue boxes are allocated, but not initialized
            -- upon declaration.
            if cmd._tag == "ir.Cmd.SetField" and cmd.rec_typ.is_upvalue_box then
                state.uninit[val.id] = nil
            end
        end
    end

    -- Artificial initializers introduced by the compilers do not count.
    if not (cmd._tag == "ir.Cmd.NewRecord" and cmd.rec_typ.is_upvalue_box) then
        for _, v_id in ipairs(ir.get_dsts(cmd)) do
            state.uninit[v_id] = nil
        end
    end
end

local function flow_analysis(block_list, state_list)
    for i,block in ipairs(block_list) do
        local state = copy_state(state_list[i])
        for _,cmd in ipairs(block.cmds) do
            test(cmd, state)
        end
        if(block.next and block.next > i) then
            merge_state(state_list[block.next], state)
        end
        if(block.jmp_false and block.jmp_false.target > i) then
            merge_state(state_list[block.jmp_false.target], state)
        end
    end
end

local function check_uninit(block, input_state)
    local state = copy_state(input_state)
    for _,cmd in ipairs(block.cmds) do
        test(cmd,state)
        for _, val in ipairs(ir.get_srcs(cmd)) do
            if val._tag == "ir.Value.LocalVar" and state.uninit[val.id] then
                coroutine.yield({v = val.id, loc = cmd.loc})
            end
        end
    end
end

function uninitialized.verify_variables(module)

    local errors = {}

    for _, func in ipairs(module.functions) do

        local nvars = #func.vars
        local nargs = #func.typ.arg_types

        local states = {}
        for b_i = 1, #func.blocks do
            states[b_i] = TState()
        end
        local entry = states[1]
        for v_i = nargs+1, nvars do
            entry.uninit[v_i] = true
        end

        flow_analysis(func.blocks, states)

        local check = coroutine.wrap(function()
            for i,b in ipairs(func.blocks) do
                local st = states[i]
                check_uninit(b, st)
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

        local exit = states[#func.blocks]
        if #func.ret_vars > 0 then
            local ret1 = func.ret_vars[1]
            if exit.uninit[ret1] then
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


