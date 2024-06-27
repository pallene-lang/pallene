-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- CONSTANT PROPAGATION
-- ====================
-- This optimization pass replaces const variables by their respective
-- literals. Doing this will help later intra-procedural optimization,
-- by allowing the inner functions to see that they are using a constant.
-- For example:
--
--     local N = 42
--     local function foo(): integer
--        return N
--     end
--
-- is converted into this:
--
--     local function foo(): integer
--         return 42
--     end

local ir = require "pallene.ir"
local tagged_union = require "pallene.tagged_union"

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
        tagged_union.error(tag)
    end
end

-- Stores the constant initializers for local variables and upvalues of a function.
local function FuncData(func)
    local fdata = {
        n_writes_of_locvar      = {}, -- { loc_id => integer  }
        locvar_constant_init    = {}, -- { loc_id => ir.Value }
        constant_val_of_upvalue = {}, -- { upv_id => ir.Value }
        new_upvalue_id          = {}, -- { upv_id => upv_id   }
    }

    for loc_id = 1, #func.vars do
        fdata.locvar_constant_init[loc_id] = false
        fdata.n_writes_of_locvar[loc_id] = 0
    end

    for u_id = 1, #func.captured_vars do
        fdata.constant_val_of_upvalue[u_id] = false
    end

    return fdata
end

-- Replaces outer constant variables by their respective values.
--
-- Currently assumes that the outer constant variable is initialized with a constant literal.
-- Does not currently recognize non-trivial constant expressions as being constant.
function constant_propagation.run(module)

    -- 1) Find which variables are initialized to a constant.

    local data_of_func = {} -- list of FuncData
    for _, func in ipairs(module.functions) do
        table.insert(data_of_func, FuncData(func))
    end


    for f_id, func in ipairs(module.functions) do
        -- DFS traversal to find the ir.Cmd.Move instructions which have constant srcs.
        -- We can look inside initializers in loops and if-statements because the uninitialized.lua
        -- pass takes care of variables that are used before being initialized.
        local f_data = assert(data_of_func[f_id])

        for cmd in ir.iter(func.blocks) do
            local tag = cmd._tag
            if     tag == "ir.Cmd.Move" then
                local id = cmd.dst
                if is_constant_value(cmd.src) then
                    f_data.locvar_constant_init[id] = cmd.src
                end

            elseif tag == "ir.Cmd.InitUpvalues" then
                for u_id, value in ipairs(cmd.srcs) do
                    local next_f = data_of_func[cmd.f_id]
                    if value._tag == "ir.Value.LocalVar" then
                        local const_init = f_data.locvar_constant_init[value.id]
                        next_f.constant_val_of_upvalue[u_id] = const_init

                    elseif value._tag == "ir.Value.Upvalue" then
                        -- A NewClosure or InitUpvalues instruction can only reference values in
                        -- outer scopes, in surrounding functions that have a lower f_id. Therefore,
                        -- if we access the functions in depth-first order then when we process a
                        -- captured upvalue we will already know whether it is a constant or not.
                        local const_init = f_data.constant_val_of_upvalue[value.id]
                        next_f.constant_val_of_upvalue[u_id] = const_init

                    else
                        tagged_union.error(value._tag)
                    end
                end

            end
        end

        for loc_id = 1, #func.typ.arg_types do
            f_data.locvar_constant_init[loc_id] = false
        end
    end

    -- 2) Find which local variables are never re-initialized.

    for f_id, func in ipairs(module.functions) do
        local f_data   = assert(data_of_func[f_id])
        local n_writes = f_data.n_writes_of_locvar

        for cmd in ir.iter(func.blocks) do
            local tag = cmd._tag
            if tag == "ir.Cmd.InitUpvalues" then
                local next_f = assert(data_of_func[cmd.f_id])
                for u_id, value in ipairs(cmd.srcs) do
                    if value._tag == "ir.Value.LocalVar" then
                        if n_writes[value.id] ~= 1 then
                            next_f.constant_val_of_upvalue[u_id] = false
                        end
                    elseif value._tag == "ir.Value.Upvalue" then
                        next_f.constant_val_of_upvalue[u_id] = f_data.constant_val_of_upvalue[value.id]
                    else
                        tagged_union.error(value._tag)
                    end
                end

            else
                local dsts = ir.get_dsts(cmd)
                for _, dst_id in ipairs(dsts) do
                    n_writes[dst_id] = n_writes[dst_id] + 1
                end
            end
        end

        -- In the following loop, we verify the assumption that an upvalue with a const initializer
        -- always references a local variable with a write count of 1. The reason for this is that
        -- the assignment_conversion converts mutable variables into a box where the contents are
        -- mutable but the binding itself is immutable. For example, the following is impossible:
        --
        --     x1 <- 10
        --     loop {
        --         x2 = NewClosure()
        --         x2.upvalues <- x1
        --         x1 <- 20
        --     }
        --
        for cmd in ir.iter(func.blocks) do
            local tag = cmd._tag
            if tag == "ir.Cmd.InitUpvalues" then
                local next_f = assert(data_of_func[cmd.f_id])
                for u_id, value in ipairs(cmd.srcs) do
                    if value._tag == "ir.Value.LocalVar" and next_f.constant_val_of_upvalue[u_id] then
                        assert(n_writes[value.id] == 1)
                    end
                end
            end
        end

    end

    --
    -- 3) Remove propagated upvalues from the capture list.
    --

    for _, func in ipairs(module.functions) do
        for cmd in ir.iter(func.blocks) do
            if cmd._tag == "ir.Cmd.InitUpvalues" then
                local next_f   = assert(data_of_func[cmd.f_id])
                local new_u_id = next_f.new_upvalue_id

                local new_srcs = {}
                for u_id, value in ipairs(cmd.srcs) do
                    if not next_f.constant_val_of_upvalue[u_id] then
                        table.insert(new_srcs, value)
                        new_u_id[u_id] = #new_srcs
                    end
                end

                cmd.srcs = new_srcs
            end
        end
    end


    -- 4) Propagate the constants local variables and upvalues.

    local function is_propagated_local(f_data, v_id)
        return (f_data.n_writes_of_locvar[v_id] == 1 and f_data.locvar_constant_init[v_id])
    end

    -- Returns a new `ir.Value` representing `src_val` after constant propagation.
    -- @param f_data  FuncData of the function whose IR contains `src_val`.
    -- @param src_val The value that we may need to update.
    local function updated_value(f_data, src_val)
        if src_val._tag == "ir.Value.LocalVar" then
            if is_propagated_local(f_data, src_val.id) then
                return f_data.locvar_constant_init[src_val.id]
            else
                return src_val
            end
        elseif src_val._tag == "ir.Value.Upvalue" then
            if f_data.constant_val_of_upvalue[src_val.id] then
                return f_data.constant_val_of_upvalue[src_val.id]
            else
                local u_id = assert(f_data.new_upvalue_id[src_val.id])
                return  ir.Value.Upvalue(u_id)
            end
        else
            return src_val
        end
    end

    for f_id, func in ipairs(module.functions) do
        local f_data = data_of_func[f_id]

        do
            local i = 0
            local new_captured_vars = {}
            local new_f_id_of_upvalue = {}
            for u_id, val in ipairs(f_data.constant_val_of_upvalue) do
                if not val then
                    i = i + 1
                    new_captured_vars[i] = func.captured_vars[u_id]
                    new_f_id_of_upvalue[i] = func.f_id_of_upvalue[u_id]
                end
            end
            func.captured_vars = new_captured_vars
            func.f_id_of_upvalue = new_f_id_of_upvalue
        end

        ir.map_cmd(func.blocks, function(cmd)
            local inputs = ir.get_value_field_names(cmd)
            for _, src_field in ipairs(inputs.src) do
                cmd[src_field] = updated_value(f_data, cmd[src_field])
            end

            for _, src_field in ipairs(inputs.srcs) do
                local srcs = cmd[src_field]
                for i, value in ipairs(srcs) do
                    srcs[i] = updated_value(f_data, value)
                end
            end

            return false
        end)
    end

    ir.clean_all(module)
    return module, {}
end

return constant_propagation
