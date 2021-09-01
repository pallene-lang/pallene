-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local ir = require "pallene.ir"
local typedecl = require "pallene.typedecl"

local constant_propagation = {}

local function is_constant_value(v)
    local tag = v._tag
    if     tag == "ir.Value.Nil"      then return true
    elseif tag == "ir.Value.Bool"     then return true
    elseif tag == "ir.Value.Integer"  then return true
    elseif tag == "ir.Value.Float"    then return true
    elseif tag == "ir.Value.String"   then return true
    elseif tag == "ir.Value.LocalVar" then return false
    elseif tag == "ir.Value.Upvalue"  then return false
    else
        typedecl.tag_error(tag)
    end
end

-- Stores the constant initializers for local variables and upvalues of a function.
local function FuncData(func)
    local fdata = {
        n_writes_of_locvar      = {}, -- { loc_id => integer  }
        is_upvalue_constant     = {}, -- { upv_id => boolean  }
        locvar_constant_init    = {}, -- { loc_id => ir.Value }
        constant_val_of_upvalue = {}, -- { upv_id => ir.Value }
        new_upvalue_id          = {}, -- { upv_id => upv_id   }
    }

    for loc_id = 1, #func.vars do
        fdata.locvar_constant_init[loc_id] = false
        fdata.n_writes_of_locvar[loc_id] = 0
    end

    for u_id = 1, #func.captured_vars do
        fdata.is_upvalue_constant[u_id] = false
        fdata.constant_val_of_upvalue[u_id] = false
    end

    return fdata
end

-- Replaces toplevel constant variables by their respective values.
--
-- Currently assumes that the toplevel constant variable is initialized with a constant literal.
-- Does not currently recognize non-trivial constant expressions as being constant.
function constant_propagation.run(module)

    -- 1) Find what toplevel variables are initialized to a constant.

    local data_of_func = {} -- list of FuncData
    for _, func in ipairs(module.functions) do
        table.insert(data_of_func, FuncData(func))
    end


    for f_id, func in ipairs(module.functions) do
        -- DFS traversal to find the ir.Cmd.Move instructions which have constant
        -- values as their src. We skip initializers in loops to make sure we only count
        -- the initializers which are guaranteed to be evaluated at runtime.
        local f_data   = assert(data_of_func[f_id])

        local stack =  { func.body }
        while #stack > 0 do
            local cmd = table.remove(stack)
            local tag = cmd._tag
            if     tag == "ir.Cmd.Move" then
                local id = cmd.dst
                if is_constant_value(cmd.src) then
                    f_data.locvar_constant_init[id] = cmd.src
                end

            elseif tag == "ir.Cmd.Seq" then
                for i = #cmd.cmds, 1, -1 do
                    table.insert(stack, cmd.cmds[i])
                end

            elseif tag == "ir.Cmd.SetUpvalues" then
                for u_id, value in ipairs(cmd.srcs) do
                    local next_f = data_of_func[cmd.f_id]
                    if value._tag == "ir.Value.LocalVar" then
                        local const_init = f_data.locvar_constant_init[value.id]
                        next_f.constant_val_of_upvalue[u_id] = const_init

                    elseif value._tag == "ir.Value.Upvalue" then
                        local const_init = f_data.constant_val_of_upvalue[value.id]
                        next_f.constant_val_of_upvalue[u_id] = const_init
                    end
                end

            end
        end
    end

    -- 2) Find which local variables are never re-initialized.

    for f_id, func in ipairs(module.functions) do
        local f_data   = assert(data_of_func[f_id])
        local n_writes = f_data.n_writes_of_locvar

        for cmd in ir.iter(func.body) do
            local tag = cmd._tag
            if tag == "ir.Cmd.SetUpvalues" then
                for u_id, value in ipairs(cmd.srcs) do
                    local next_f = assert(data_of_func[cmd.f_id])

                    if value._tag == "ir.Value.LocalVar" then
                        next_f.is_upvalue_constant[u_id] = n_writes[value.id] == 1
                            and f_data.locvar_constant_init[value.id]
                    elseif value._tag == "ir.Value.Upvalue" then
                        next_f.is_upvalue_constant[u_id] = f_data.is_upvalue_constant[value.id]
                    end
                end

            else
                local dsts = ir.get_dsts(cmd)
                for _, dst_id in ipairs(dsts) do
                    n_writes[dst_id] = n_writes[dst_id] + 1
                end
            end
        end
    end

    -- 3) Remove propagated upvalues from the capture list.
    for _, func in ipairs(module.functions) do
        for cmd in ir.iter(func.body) do
            if cmd._tag == "ir.Cmd.SetUpvalues" then
                local next_f   = assert(data_of_func[cmd.f_id])
                local ir_func  = module.functions[cmd.f_id]
                local new_u_id = next_f.new_upvalue_id

                local new_srcs = {}
                for u_id, value in ipairs(cmd.srcs) do
                    if not next_f.is_upvalue_constant[u_id] then
                        table.insert(new_srcs, value)
                        new_u_id[u_id] = #new_srcs
                    end
                end

                cmd.srcs = new_srcs
                ir_func.num_upvalues = #cmd.srcs
            end
        end
    end


    -- 4) Propagate the constants local variables and upvalues.

    for f_id, func in ipairs(module.functions) do
        local f_data = data_of_func[f_id]
        local n_writes = f_data.n_writes_of_locvar
        local new_u_id = f_data.new_upvalue_id

        func.body = ir.map_cmd(func.body, function(cmd)
            local inputs = ir.get_value_field_names(cmd)
            for _, src_field in ipairs(inputs.src) do
                local val = cmd[src_field]
                if val._tag == "ir.Value.LocalVar"
                   and n_writes[val.id] == 1
                   and val.id > #func.typ.arg_types
                   and f_data.locvar_constant_init[val.id] then

                    cmd[src_field] = f_data.locvar_constant_init[val.id]

                elseif val._tag == "ir.Value.Upvalue" then
                    if f_data.is_upvalue_constant[val.id] then
                        cmd[src_field] = f_data.constant_val_of_upvalue[val.id]
                    else
                        local u_id = assert(new_u_id[val.id])
                        cmd[src_field] = ir.Value.Upvalue(u_id)
                    end
                end
            end

            return false
        end)
    end

    ir.clean_all(module)
    return module, {}
end

return constant_propagation
