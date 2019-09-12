local types = require "pallene.types"

local gc = {}

-- Determines now many Lua stack slots we need to store our GC variables,
-- and what slot each variable should be assigned to.
function gc.compute_stack_slots(func)
    -- Very dumb implementation. Each variable goes in its own slot.

    local slot_of_variable = {} -- var_id => (false | integer)

    local frame_size = 0
    for v_id = 1, #func.vars do
        local typ = func.vars[v_id].typ
        if types.is_gc(typ) then
            frame_size = frame_size + 1
            slot_of_variable[v_id] = frame_size
        else
            slot_of_variable[v_id] = false
        end
    end

    return {
        frame_size = frame_size,
        slot_of_variable = slot_of_variable,
    }
end

return gc
