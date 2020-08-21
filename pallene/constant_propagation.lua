-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local ir = require "pallene.ir"

local constant_propagation = {}

local function is_constant_value(v)
    local tag = v._tag
    if     tag == "ir.Value.Nil"      then return true
    elseif tag == "ir.Value.Bool"     then return true
    elseif tag == "ir.Value.Integer"  then return true
    elseif tag == "ir.Value.Float"    then return true
    elseif tag == "ir.Value.String"   then return true
    elseif tag == "ir.Value.LocalVar" then return false
    elseif tag == "ir.Value.Function" then return true
    else
        error("impossible")
    end
end

-- Replaces toplevel constant variables by their respective values.
--
-- Currently assumes that the toplevel constant variable is initialized with a constant literal.
-- Does not currently recognize non-trivial constant expressions as being constant.
function constant_propagation.run(module)

    local n_globals = #module.globals

    -- 1) Find what toplevel variables are initialized to a constant in $init

    local constant_initializer = {} -- { g_id => ir.Value? }
    for i = 1, n_globals do
        constant_initializer[i] = false
    end

    do
        -- DFS traversal to find SetGlobal instructions with a constant initializer. We ignore the
        -- instructions inside If, Loop, and For statements, since those might be skipped.
        local stack = { module.functions[1].body }
        while #stack > 0 do
            local cmd = table.remove(stack)
            local tag = cmd._tag
            if     tag == 'ir.Cmd.SetGlobal' then
                if is_constant_value(cmd.src) then
                    constant_initializer[cmd.global_id] = cmd.src
                end
            elseif tag == 'ir.Cmd.Seq' then
                for i = #cmd.cmds, 1, -1 do
                    table.insert(stack, cmd.cmds[i])
                end
            else
                -- skip
            end
        end
    end

    -- 2) Find what toplevel variables are never re-initialized or never used

    local n_reads  = {} -- { g_id => int }
    local n_writes = {} -- { g_id => int }
    for i = 1, n_globals do
        n_reads[i]  = 0
        n_writes[i] = 0
    end

    for _, func in ipairs(module.functions) do
        for cmd in ir.iter(func.body) do
            local tag = cmd._tag
            if     tag == "ir.Cmd.GetGlobal" then
                local id = cmd.global_id
                n_reads[id] = n_reads[id] + 1
            elseif tag == "ir.Cmd.SetGlobal" then
                local id = cmd.global_id
                n_writes[id] = n_writes[id] + 1
            else
                -- skip
            end
        end
    end

    -- 3) Find out which constant globals should be propagated, and which unused constant globals
    -- should be simply eliminated.

    local is_exported = {}
    for _, g_id in ipairs(module.exported_globals) do
        is_exported[g_id] = true
    end

    local new_globals = {}
    local new_global_id = {} -- { g_id => g_id? }
    for i = 1, n_globals do
        if constant_initializer[i] and not is_exported[i] and (n_reads[i] == 0 or n_writes[i] == 1) then
            new_global_id[i] = false
        else
            table.insert(new_globals, module.globals[i])
            new_global_id[i] = #new_globals
        end
    end

    -- 4) Propagate the constant globals, and rename the existing ones accordingly

    for i, g_id in ipairs(module.exported_globals) do
        module.exported_globals[i] = assert(new_global_id[g_id])
    end

    module.globals = new_globals

    for _, func in ipairs(module.functions) do
        func.body = ir.map_cmd(func.body, function(cmd)
            local tag = cmd._tag
            if     tag == "ir.Cmd.GetGlobal" then
                local old_id = cmd.global_id
                local new_id = new_global_id[old_id]
                if new_id then
                    return ir.Cmd.GetGlobal(cmd.loc, cmd.dst, new_id)
                else
                    local v = assert(constant_initializer[old_id])
                    return ir.Cmd.Move(cmd.loc, cmd.dst, v)
                end
            elseif tag == "ir.Cmd.SetGlobal" then
                local old_id = cmd.global_id
                local new_id = new_global_id[old_id]
                if new_id then
                    return ir.Cmd.SetGlobal(cmd.loc, new_id, cmd.src)
                else
                    return ir.Cmd.Nop()
                end
            else
                -- don't modify
                return false
            end
        end)
    end

    -- 5) Done

    ir.clean_all(module)
    return module, {}
end

return constant_propagation
