-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- In this module we use data-flow analysis to detect when variables are used before being
-- initialized and when control flows to the end of a non-void function without returning. Make sure
-- that you call ir.clean first, so that it does the right thing in the presence of `while true`
-- loops.

local ir = require "pallene.ir"
local flow = require "pallene.flow"

local uninitialized = {}

function uninitialized.verify_variables(module)

    local errors = {}

    for _, func in ipairs(module.functions) do

        local nvars = #func.vars
        local nargs = #func.typ.arg_types

        -- solve flow equations
        local function init_start(start_set, block_index)
            if block_index == 1 then
                for v_i = nargs+1, nvars do
                    start_set[v_i] = true
                end
            end
        end

        local function compute_gen_kill(block_i, cmd_i)
            local cmd = func.blocks[block_i].cmds[cmd_i]
            local gk = flow.GenKill()
            for _, src in ipairs(ir.get_srcs(cmd)) do
                if src._tag == "ir.Value.LocalVar" then
                    -- `SetField` instructions can count as initializers when the target is an
                    -- upvalue box. This is because upvalue boxes are allocated, but not initialized
                    -- upon declaration.
                    if cmd._tag == "ir.Cmd.SetField" and cmd.rec_typ.is_upvalue_box then
                        flow.kill_value(gk, src.id)
                    end
                end
            end

            -- Artificial initializers introduced by the compilers do not count.
            if not (cmd._tag == "ir.Cmd.NewRecord" and cmd.rec_typ.is_upvalue_box) then
                for _, v_id in ipairs(ir.get_dsts(cmd)) do
                    flow.kill_value(gk, v_id)
                end
            end
            return gk
        end

        local flow_info = flow.FlowInfo(flow.Order.Forward, compute_gen_kill, init_start)
        local sets_list = flow.flow_analysis(func.blocks, flow_info)

        -- check for errors
        local reported_variables = {} -- (only one error message per variable)
        for block_i, block in ipairs(func.blocks) do
            local uninit = sets_list[block_i]
            for cmd_i, cmd in ipairs(block.cmds) do
                local loc = cmd.loc
                flow.update_set(uninit, flow_info, block_i, cmd_i)
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

        local exit_uninit = sets_list[#func.blocks]
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
