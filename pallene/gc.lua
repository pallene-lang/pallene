local ir = require "pallene.ir"
local types = require "pallene.types"

local gc = {}

-- For proper garbage collection in Pallene, we must ensure that at every
-- potential garbage collection point the values of all live variables with a
-- GC type are saved into the Lua stack.
--
-- Per the Pallene calling convention, functions can assume that the initial
-- values of function parameters have already been saved by the caller.
--
-- Potential garbage collection points are explicit ir.CheckGC nodes and
-- function calls.
--
-- Our implementation of variable saving is to mirror writes to the Lua stack
-- if at any point in the function the corresponding variable is live at a
-- GC point.
--
-- This analysis could be made more precise in the following ways, which may or
-- may not be worth the trouble of implementing in the future:
--
--   1) Insert fewer checkGC calls in our functions, or move the checkGC calls
--      to places with fewer live variables. (For example, the end of the scope)
--   2) Identifiy functions that don't call the GC (directly or indirectly)
--      and don't treat calls to them as potential GC sites
--   3) Use a flow-based liveleness analysis to precisely identify the commands
--      that a variable appears live at, instead of approximating with first
--      definition and last use.
--   4) Use SSA form or some form of reaching definitions analysis so that we
--      we only need to mirror the writes that reach a GC site, instead of
--      always mirroring all writes to a variable if one of them reaches a GC
--      site.
--
function gc.compute_stack_slots(func)

    local flat_cmds = ir.flatten_cmd(func.body)

    -- 1) Compute approximated live intervals for GC variables defined by the
    --    function. Input variables are only counted if they are redefined,
    --    since their original value was already saved by the caller.

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
    for i = 1, #func.typ.ret_types do
        local v = ir.ret_var(func, i)
        last_use[v] = #flat_cmds + 1
    end

    -- 2) Find which variables are live at each GC and, conversely,
    --    which variables are live at some GC slot.

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

    -- 3) Allocate variables to stack slots, ensuring that variables with
    --    overlapping lifetimes use different stack slots.
    --    NOTE: stack slots are 0-based, to match C

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
