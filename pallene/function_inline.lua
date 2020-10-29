-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local ir = require "pallene.ir"
local util = require "pallene.util"

local function_inline = {}


-- return moves corresponding to each argument as they where at the beginning of the inner scope
local function args_to_moves(args,cmd,top)
    local arguments = {}
    for k,_ in ipairs(args) do
        -- in PIR, the variable name convention is arg1 -> x1, arg2 -> x2 ... argN -> xN
        -- and then local and temps use values starting from N+1
        -- so we can just use the srcs from the call (the arguments) on the rhs of the 'move' commands
        -- at the same time, it is also convenient to adjust the dst (lhs) of the 'move'
        -- to values that will not collide with the outer scope (adding top)
        table.insert(arguments,ir.Cmd.Move(cmd.loc, k+top, cmd.srcs[k]))
    end
    return ir.Cmd.Seq(arguments)
end

-- changes the called function (a copy preferably) in place.
-- each return is turned into a sequence of moves.
local function return_to_moves(called,cmd)
    return ir.map_cmd(called,function (_cmd)
        if _cmd._tag == 'ir.Cmd.Return' then
            local moves = {}
            for k,v in ipairs(_cmd.srcs) do
                -- if the function call will put the results into a,b,c
                -- and the called returns x,y,z
                -- this creates moves corresponding to x = a, y = b and z = c
                table.insert(moves,ir.Cmd.Move(_cmd.loc,cmd.dsts[k],v))
            end
            return ir.Cmd.Seq(moves)
        end
    end)
end


-- find_top finds the highest variable index in the 'cmd' subtree
local function find_top(cmd)
    local top = 0
    local function change_top(val)
        if val > top then top = val end
    end
    local function findtop_localvar(val)
        if type(val) == "table" and val._tag == 'ir.Value.LocalVar' then
            change_top(val.id)
        end
    end
    local function findtop(_cmd)
        if _cmd._tag == 'ir.Cmd.Binop' then
            change_top(_cmd.dst)
            findtop_localvar(_cmd.src1)
            findtop_localvar(_cmd.src2)
            return _cmd
        end
        if _cmd._tag == 'ir.Cmd.Move' then
            change_top(_cmd.dst)
            return _cmd
        end
        if _cmd._tag == 'ir.Cmd.Return' then

            for _, value in pairs(_cmd.srcs) do
                findtop_localvar(value)
            end
            return _cmd
        end
    end
    ir.map_cmd(cmd,findtop)
    return top
end

-- auxiliary function to transform values
local function map_val(cmd,fval,flocalval)
    return ir.map_cmd(cmd,function (_cmd)
        if _cmd._tag == 'ir.Cmd.Binop' then
            _cmd.src1 = flocalval(_cmd.src1)
            _cmd.src2 = flocalval(_cmd.src2)
            _cmd.dst = fval(_cmd.dst)
            return _cmd
        end
        if _cmd._tag == 'ir.Cmd.Move' then
            _cmd.src = flocalval(_cmd.src)
            _cmd.dst = fval(_cmd.dst)
            return _cmd
        end
        if _cmd._tag == 'ir.Cmd.Return' then
            for key, value in pairs(_cmd.srcs) do
                _cmd.srcs[key] = flocalval(value)
            end
            return _cmd
        end
    end)
end

-- adjusts the function body to be inlined in respect to the outer function top
-- so the internal variables will not collide with the outer ones
local function adjust(cmd,top)
    local new_val = function(val)
        return top+val
    end
    local iflocalvar_new_val = function (val)
        if type(val) == "table" and val._tag == 'ir.Value.LocalVar' then
            val.id = new_val(val.id)
        end
        return val
    end
    return map_val(cmd,new_val,iflocalvar_new_val)
end

-- normal_form guarantess that the cmd subtree will be in normal form
-- starting at 1 and every value is increased in order of appearance, without holes
local function normal_form(cmd)
    local ids = {}
    ids.top = 1
    local new_val = function(val)
        if not ids[val] then
            ids[val] = ids.top
            ids.top = ids.top + 1
        end
        return ids[val]
    end

    local iflocalvar_new_val = function (val)
        if type(val) == "table" and val._tag == 'ir.Value.LocalVar' then
            val.id = new_val(val.id)
        end
        return val
    end

    return map_val(cmd,new_val,iflocalvar_new_val)
end

-- transform a whole module into normal form
-- now used just for testing purposes
function function_inline.to_normal_module(module)
    for _, func in ipairs(module.functions) do
        func.body = normal_form(func.body)
    end
end


function function_inline.inline(module)

    local errors = {}

    for k, func in ipairs(module.functions) do



        -- top is the highest variable present in the host function
        local top = find_top(func.body)+1

        module.functions[k].body = ir.map_cmd(func.body,function(cmd)
            if cmd._tag == 'ir.Cmd.CallStatic' then
                local called = util.copy(module.functions[cmd.f_id].body)
                local args = args_to_moves(module.functions[cmd.f_id].typ.arg_types,cmd,top)
                local body = adjust(called,top)
                local rets = return_to_moves(body,cmd)
                return ir.Cmd.Seq({args,rets})
            end
        end)
    end

    if #errors == 0 then
        return module, {}
    else
        return false, errors
    end
end

return function_inline


