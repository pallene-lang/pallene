-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local ir = require "pallene.ir"
local types = require "pallene.types"

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
-- it reaches a potential garbage collection site. The current analysis is pretty simple, and there
-- are many ways to make it more precise. So we don't forget, I'm listing some of the ideas here...
-- But it should be said that we don't know if implementing them would be worth the trouble.
--
--   1) Insert fewer checkGC calls in our functions, or move the checkGC calls to places with fewer
--      live variables. (For example, the end of the scope)
--
--   2) Identify functions that don't call the GC (directly or indirectly) and don't treat calls to
--      them as potential GC sites. (Function inlining might mitigate this for small functions)
--
--   3) Use a flow-based liveliness analysis to precisely identify the commands that a variable
--      appears live at, instead of approximating with first definition and last use.
--
--   4) Use SSA form or some form of reaching definitions analysis so that we we only need to mirror
--      the writes that reach a GC site, instead of always mirroring all writes to a variable if one
--      of them reaches a GC site.

local gc = {}

function gc.compute_stack_slots(func)

    local flat_cmds = ir.flatten_cmd(func.blocks)

    -- 1) Compute approximated live intervals for GC variables defined by the function. Function
    -- parameters are only counted if they are redefined, since their original value was already
    -- saved by the caller. Also note that we only care about variables, not about upvalues.
    -- The latter are already exposed to the GC via the function closures.

    local defined_variables = {} -- { var_id }, sorted by first definition
    local last_use          = {} -- { var_id => integer }
    local first_definition  = {} -- { var_id => integer }

    for i, cmd in ipairs(flat_cmds) do
        for _, val in ipairs(ir.get_srcs(cmd)) do
            if val._tag == "ir.Value.LocalVar" then
                local v_id = val.id
                last_use[v_id] = i
            end
        end
        for _, v_id in ipairs(ir.get_dsts(cmd)) do
            local typ = func.vars[v_id].typ
            if types.is_gc(typ) and not first_definition[v_id] then
                first_definition[v_id] = i
                table.insert(defined_variables, v_id)
            end
        end
    end

    -- 2) Find which variables are live at each GC spot in the program.

    local live_gc_vars = {} -- { cmd => {var_id}? }
    for i, cmd in ipairs(flat_cmds) do
        local tag = cmd._tag
        if
            tag == "ir.Cmd.CallStatic" or
            tag == "ir.Cmd.CallDyn" or
            tag == "ir.Cmd.CheckGC"
        then
            live_gc_vars[cmd] = {}
            for _, v_id in ipairs(defined_variables) do
                local a = first_definition[v_id]
                local b = last_use[v_id]
                if a and b and a < i and i <= b then
                    table.insert(live_gc_vars[cmd], v_id)
                end
            end
        end
    end

    local variable_is_live_at_gc = {}  -- { var_id => boolean }
    for v_id = 1, #func.vars do
        variable_is_live_at_gc[v_id] = false
    end
    for _, v_ids in pairs(live_gc_vars) do
        for _, v_id in ipairs(v_ids) do
            variable_is_live_at_gc[v_id] = true
        end
    end

    -- 3) Allocate variables to Lua stack slots, ensuring that variables with overlapping lifetimes
    -- different stack slots. IMPORTANT: stack slots are 0-based. The C we generate prefers that.

    local max_frame_size = 0
    local slot_of_variable = {} -- { var_id => integer? }

    for v_id = 1, #func.vars do
        slot_of_variable[v_id] = false
    end

    local n = 0
    local stack = { } -- { var_id }
    for _, v_id in ipairs(defined_variables) do
        if variable_is_live_at_gc[v_id] then
            local def = first_definition[v_id]
            while n > 0 and last_use[stack[n]] <= def do
                stack[n] = nil
                n = n - 1
            end

            n = n + 1
            slot_of_variable[v_id] = n-1
            stack[n] = v_id
            max_frame_size = math.max(max_frame_size, n)
        end
    end

    return {
        live_gc_vars = live_gc_vars,
        max_frame_size = max_frame_size,
        slot_of_variable = slot_of_variable,
    }
end

return gc
