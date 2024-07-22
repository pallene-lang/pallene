-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- In this module we use data-flow analysis to detect when variables are used before being
-- initialized and when control flows to the end of a non-void function without returning. Make sure
-- that you call ir.clean first, so that it does the right thing in the presence of `while true`
-- loops.

local ir = require "pallene.ir"
local tagged_union = require "pallene.tagged_union"

local uninitialized = {}

local function FlowState()
    return {
        input  = {},  -- {var_id -> bool?} uninitialized variables at block start
        output = {},  -- {var_id -> bool?} uninitialized variables at block end
        kill   = {},  -- {var_id -> bool?} variables that are initialized inside block
    }
end

local function copy_set(S)
    local new_set = {}
    for v,_ in pairs(S) do
        new_set[v] = true
    end
    return new_set
end

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

local function flow_analysis(block_list, state_list)
    local function apply_kill_set(flow_state)
        local input = flow_state.input
        local output = flow_state.output
        local kill = flow_state.kill
        local out_changed = false
        for v, _ in pairs(input) do
            if not kill[v] then
                if not output[v] then
                    out_changed = true
                end
                output[v] = true
            end
        end

        for v, _ in pairs(output) do
            if not input[v] then
                output[v] = nil
                out_changed = true
            end
        end
        return out_changed
    end

    local function merge_uninit(input, output)
        for v, _ in pairs(output) do
            input[v] = true
        end
    end

    local function clear_set(S)
        for v,_ in pairs(S) do
            S[v] = nil
        end
    end

    local succ_list = ir.get_successor_list(block_list)
    local pred_list = ir.get_predecessor_list(block_list)
    local block_order = ir.get_successor_depth_search_topological_sort(succ_list)

    local dirty_flag = {} -- { block_id -> bool? } keeps track of modified blocks
    for i = 1, #block_list do
        dirty_flag[i] = true
    end

    local function update_block(block_i)
        local block_succs = succ_list[block_i]
        local block_preds = pred_list[block_i]
        local state = state_list[block_i]

        -- first block's input is supposed to be fixed
        if block_i ~= 1 then
            clear_set(state.input)
            for _,pred in ipairs(block_preds) do
                local pred_out = state_list[pred].output
                merge_uninit(state.input, pred_out)
            end
        end

        local out_changed = apply_kill_set(state)
        if out_changed then
            for _, succ in ipairs(block_succs) do
                dirty_flag[succ] = true
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
                dirty_flag[block_i] = false
                update_block(block_i)
            end
        end
    until not found_dirty_block
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

        local state_list = {} -- { FlowState }
        -- initialize states
        for block_i,block in ipairs(func.blocks) do
            local fst = FlowState()
            fst.kill = gen_kill_set(block)
            state_list[block_i] = fst
        end
        local entry_input = state_list[1].input
        for v_i = nargs+1, nvars do
            entry_input[v_i] = true
        end

        -- solve flow equations
        flow_analysis(func.blocks, state_list)

        -- check for errors
        local reported_variables = {} -- (only one error message per variable)
        for block_i, block in ipairs(func.blocks) do
            local uninit = copy_set(state_list[block_i].input)
            for _, cmd in ipairs(block.cmds) do
                local loc = cmd.loc
                fill_set(cmd, uninit, nil)
                for _, src in ipairs(ir.get_srcs(cmd)) do
                    local v = src.id
                    if src._tag == "ir.Value.LocalVar" and uninit[v] then
                        if not reported_variables[v] then
                            reported_variables[v] = true
                            local name = assert(func.vars[v].name)
                            table.insert(errors, loc:format_error(
                                "error: variable '%s' is used before being initialized", name))
                        end
                    end
                end
            end
        end

        local exit_uninit = state_list[#func.blocks].output
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
