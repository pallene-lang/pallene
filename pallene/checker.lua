local checker = {}

local ast = require "pallene.ast"
local builtins = require "pallene.builtins"
local location = require "pallene.location"
local types = require "pallene.types"

local type_check

local check_program
local check_type
local check_top_level
local check_decl
local check_stat
--local check_then
local check_var
local check_exp
--local check_field

-- Type-check a Pallene module
--
-- Sets a _type field on some AST nodes:
--  - Value declarations:
--      - ast.Toplevel.Func
--      - ast.Toplevel.Var
--      - ast.Decl.Decl
--  - ast.Exp
--  - ast.Var
--
-- Sets a _field_types field on ast.Toplevel.Record nodes, mapping field names
-- to their types.
--
-- @ param prog_ast AST for the whole module
-- @ return true or false, followed by as list of compilation errors
function checker.check(prog_ast)
    return type_check(prog_ast)
end

--
-- local functions
--

local function type_error(loc, fmt, ...)
    local err_msg = location.format_error(loc, "type error: "..fmt, ...)
    coroutine.yield(err_msg)
end

-- Checks if two types are the same, and raises an error message otherwise
--   loc: location of the term that is being compared
--   expected: type that is expected
--   found: type that was actually present
--   errmsg_fmt: format string describing what part of the program is
--               responsible for this type check
--   ...: arguments to the "errmsg_fmt" format string
local function check_match(loc, expected, found, errmsg_fmt, ...)
    if not types.equals(expected, found) then
        local msg = string.format(
            "expected %s but found %s in %s",
            types.tostring(expected),
            types.tostring(found),
            string.format(errmsg_fmt, ...))
        type_error(loc, msg)
    end
end

local function try_coerce(exp, expected, errmsg_fmt, ...)
    local found = exp._type
    if types.equals(found, expected) then
        return exp
    elseif types.consistent(found, expected) then
        local cast = ast.Exp.Cast(exp.loc, exp, false)
        cast._type = expected
        return cast
    else
        local msg = string.format(
            "expected %s but found %s in %s",
            types.tostring(expected),
            types.tostring(found),
            string.format(errmsg_fmt, ...))
        type_error(exp.loc, msg)
    end
end

local function is_numeric_type(typ)
    return typ._tag == "types.T.Integer" or typ._tag == "types.T.Float"
end

local function coerce_numeric_exp_to_float(exp)
    if exp._type._tag == "types.T.Integer" then
        local name = ast.Var.Name(false, "tofloat")
        name._decl = builtins.tofloat
        local tofloat = ast.Exp.Var(false, name)
        local call = ast.Exp.CallFunc(false, tofloat, {exp})
        check_exp(call, types.T.Float())
        return call
    elseif exp._type._tag == "types.T.Float" then
        return exp
    else
        error("not a numeric type")
    end
end

-- Does this statement always call "return"?
--
-- In the future I would like to get rid of the function, and make it a part of
-- live-variable analysis. (A possibly-uninitialized "return variable" signifies
-- a missing return statement.)
local function stat_always_returns(stat)
    local tag = stat._tag
    if     tag == "ast.Stat.Decl" then
        return false
    elseif tag == "ast.Stat.Block" then
        for _, inner_stat in ipairs(stat.stats) do
            if stat_always_returns(inner_stat) then
                return true
            end
        end
        return false
    elseif tag == "ast.Stat.While" then
        return false
    elseif tag == "ast.Stat.Repeat" then
        return false
    elseif tag == "ast.Stat.For" then
        return false
    elseif tag == "ast.Stat.Assign" then
        return false
    elseif tag == "ast.Stat.Call"  then
        return false
    elseif tag == "ast.Stat.Return" then
        return true
    elseif tag == "ast.Stat.If" then
        return stat_always_returns(stat.then_) and
                stat_always_returns(stat.else_)
    else
        error("impossible")
    end
end

--
-- check
--

type_check = function(prog_ast)
    local co = coroutine.create(check_program)
    local ok, err_msg = coroutine.resume(co, prog_ast)
    if ok then
        if coroutine.status(co) == "dead" then
            -- User's program passed type checker
            return prog_ast, {}
        else
            -- User's program has a type error
            return false, {err_msg}
        end
    else
        -- Unhandled exception in Palene's type checker
        local stack_trace = debug.traceback(co)
        error(err_msg .. "\n" .. stack_trace)
    end
end

check_program = function(prog_ast)
    for _, tl_node in ipairs(prog_ast) do
        check_top_level(tl_node)
    end
end

check_type = function(typ)
    local tag = typ._tag
    if     tag == "ast.Type.Nil" then
        return types.T.Nil()

    elseif tag == "ast.Type.Boolean" then
        return types.T.Boolean()

    elseif tag == "ast.Type.Integer" then
        return types.T.Integer()

    elseif tag == "ast.Type.Float" then
        return types.T.Float()

    elseif tag == "ast.Type.String" then
        return types.T.String()

    elseif tag == "ast.Type.Value" then
        return types.T.Value()

    elseif tag == "ast.Type.Name" then
        local decl = typ._decl
        if decl._tag == "ast.Toplevel.Record" then
            return assert(decl._type)
        else
            type_error(typ.loc, "'%s' isn't a type", typ.name)
        end

    elseif tag == "ast.Type.Array" then
        local subtype = check_type(typ.subtype)
        if subtype._tag == "types.T.Nil" then
            type_error(typ.loc, "array of nil is not allowed")
        end
        return types.T.Array(subtype)

    elseif tag == "ast.Type.Function" then
        if #typ.ret_types >= 2 then
            error("functions with 2+ return values are not yet implemented")
        end
        local p_types = {}
        for _, p_type in ipairs(typ.arg_types) do
            table.insert(p_types, check_type(p_type))
        end
        local ret_types = {}
        for _, ret_type in ipairs(typ.ret_types) do
            table.insert(ret_types, check_type(ret_type))
        end
        return types.T.Function(p_types, ret_types)

    else
        error("impossible")
    end
end

check_top_level = function(tl_node)
    local tag = tl_node._tag
    if     tag == "ast.Toplevel.Import" then
        type_error(tl_node.loc, "modules are not implemented yet")

    elseif tag == "ast.Toplevel.Var" then
        if tl_node.decl.type then
            tl_node._type = check_type(tl_node.decl.type)
            check_exp(tl_node.value, tl_node._type)
            check_match(tl_node.loc,
                tl_node._type, tl_node.value._type,
                "declaration of module variable %s", tl_node.decl.name)
        else
            check_exp(tl_node.value, false)
            tl_node._type = tl_node.value._type
        end

    elseif tag == "ast.Toplevel.Func" then
        if #tl_node.ret_types >= 2 then
            error("functions with 2+ return values are not yet implemented")
        end

        local p_types = {}
        for _, param in ipairs(tl_node.params) do
            param._type = check_type(param.type)
            table.insert(p_types, param._type)
        end

        local ret_types = {}
        for _, rt in ipairs(tl_node.ret_types) do
            table.insert(ret_types, check_type(rt))
        end
        tl_node._type = types.T.Function(p_types, ret_types)

        check_stat(tl_node.block, ret_types)

        if #tl_node._type.ret_types > 0 and
           not stat_always_returns(tl_node.block)
        then
            type_error(tl_node.loc,
                "control reaches end of function with non-empty return type")
        end

    elseif tag == "ast.Toplevel.Record" then
        local name = tl_node.name
        local field_names = {}
        local field_types = {}

        for _, field_decl in ipairs(tl_node.field_decls) do
            local field_name = field_decl.name
            local typ = check_type(field_decl.type)
            table.insert(field_names, field_name)
            field_types[field_name] = typ
        end

        tl_node._type = types.T.Record(name, field_names, field_types)

    else
        error("impossible")
    end
end

check_decl = function(decl)
    decl._type = decl._type or check_type(decl.type)
end

-- @param ret_types Declared function return types (for return statements)
check_stat = function(stat, ret_types)
    local tag = stat._tag
    if     tag == "ast.Stat.Decl" then
        if stat.decl.type then
            check_decl(stat.decl)
            check_exp(stat.exp, stat.decl._type)
            stat.exp = try_coerce(stat.exp, stat.decl._type,
                "declaration of local variable %s", stat.decl.name)
        else
            check_exp(stat.exp, false)
            stat.decl._type = stat.exp._type
            check_decl(stat.decl)
        end

    elseif tag == "ast.Stat.Block" then
        for _, inner_stat in ipairs(stat.stats) do
            check_stat(inner_stat, ret_types)
        end

    elseif tag == "ast.Stat.While" then
        check_exp(stat.condition, false)
        check_match(stat.condition.loc,
            types.T.Boolean(), stat.condition._type,
            "while loop condition")
        check_stat(stat.block, ret_types)

    elseif tag == "ast.Stat.Repeat" then
        for _, inner_stat in ipairs(stat.block.stats) do
            check_stat(inner_stat, ret_types)
        end
        check_exp(stat.condition, false)
        check_match(stat.condition.loc,
            types.T.Boolean(), stat.condition._type,
            "repeat-until loop condition")

    elseif tag == "ast.Stat.For" then
        if stat.decl.type then
            check_decl(stat.decl)
        else
            stat.decl._type = false
        end

        check_exp(stat.start, stat.decl._type)
        check_exp(stat.limit, stat.decl._type)
        if stat.step then
            check_exp(stat.step, stat.decl._type)
        end
        if not stat.decl.type then
            stat.decl._type = stat.start._type
        end

        if     stat.decl._type._tag == "types.T.Integer" then
            if not stat.step then
                stat.step = ast.Exp.Integer(stat.limit.loc, 1)
                stat.step._type = types.T.Integer()
            end
        elseif stat.decl._type._tag == "types.T.Float" then
            if not stat.step then
                stat.step = ast.Exp.Float(stat.limit.loc, 1.0)
                stat.step._type = types.T.Float()
            end
        else
            type_error(stat.decl.loc,
                "expected integer or float but found %s in for-loop control variable '%s'",
                types.tostring(stat.decl._type),
                stat.decl.name)
        end

        check_match(stat.start.loc,
            stat.decl._type, stat.start._type,
            "numeric for-loop initializer")

        check_match(stat.limit.loc,
            stat.decl._type, stat.limit._type,
            "numeric for-loop limit")

        check_match(stat.step.loc,
            stat.decl._type, stat.step._type,
            "numeric for-loop step")

        check_stat(stat.block, ret_types)

    elseif tag == "ast.Stat.Assign" then
        check_var(stat.var)
        check_exp(stat.exp, stat.var._type)
        stat.exp = try_coerce(stat.exp, stat.var._type, "assignment")
        if stat.var._tag == "ast.Var.Name" and
            stat.var._decl._tag == "ast.Toplevel.Func"
        then
            type_error(stat.loc,
                "attempting to assign to toplevel constant function %s",
                stat.var.name)
        end

    elseif tag == "ast.Stat.Call" then
        check_exp(stat.call_exp, false)

    elseif tag == "ast.Stat.Return" then
        assert(#ret_types <= 1)
        if #stat.exps ~= #ret_types then
            type_error(stat.loc,
                "returning %d value(s) but function expects %s",
                #stat.exps, #ret_types)
        end

        for i = 1, #stat.exps do
            local exp = stat.exps[i]
            local ret_type = ret_types[i]
            check_exp(exp, ret_type)
            stat.exps[i] = try_coerce(exp, ret_type, "return statement")
        end

    elseif tag == "ast.Stat.If" then
        local cond = stat.condition
        check_exp(cond, false)
        check_match(cond.loc,
            types.T.Boolean(), cond._type,
            "if statement condition")

        check_stat(stat.then_, ret_types)
        check_stat(stat.else_, ret_types)

    else
        error("impossible")
    end
end

check_var = function(var)
    local tag = var._tag
    if     tag == "ast.Var.Name" then
        local decl = var._decl
        if decl._tag == "ast.Toplevel.Var" or
            decl._tag == "ast.Toplevel.Func" or
            decl._tag == "ast.Toplevel.Builtin" or
            decl._tag == "ast.Decl.Decl"
        then
            var._type = var._decl._type
        else
            type_error(var.loc, "'%s' isn't a value", var.name)
        end

    elseif tag == "ast.Var.Dot" then
        check_exp(var.exp, false)
        local exp_type = var.exp._type
        if exp_type._tag == "types.T.Record" then
            local field_type = exp_type.field_types[var.name]
            if field_type then
                var._type = field_type
            else
                type_error(var.loc,
                    "field '%s' not found in record '%s'",
                    var.name, types.tostring(exp_type))
            end
        else
            type_error(var.loc,
                "trying to access a member of value of type '%s'",
                types.tostring(exp_type))
        end

    elseif tag == "ast.Var.Bracket" then
        check_exp(var.t, false)
        if var.t._type._tag ~= "types.T.Array" then
            type_error(var.t.loc,
                "expected array but found %s in array indexing",
                types.tostring(var.t._type))
        end
        var._type = var.t._type.elem
        check_exp(var.k, false)
        check_match(var.k.loc,
            types.T.Integer(), var.k._type,
            "array indexing")

    else
        error("impossible")
    end
end

-- @param type_hint Expected type; Used to infer polymorphic/record constructors.
check_exp = function(exp, type_hint)
    assert(type_hint ~= nil)

    local tag = exp._tag
    if     tag == "ast.Exp.Nil" then
        exp._type = types.T.Nil()

    elseif tag == "ast.Exp.Bool" then
        exp._type = types.T.Boolean()

    elseif tag == "ast.Exp.Integer" then
        exp._type = types.T.Integer()

    elseif tag == "ast.Exp.Float" then
        exp._type = types.T.Float()

    elseif tag == "ast.Exp.String" then
        exp._type = types.T.String()

    elseif tag == "ast.Exp.Initlist" then
        -- Determining the type for a table initializer *requires* a type hint.
        -- In theory, we could try to infer the type without a type hint for
        -- non-empty arrays whose contents are inferrable, but I am not sure
        -- we should treat that case differently from the others...
        --
        if not type_hint then
            type_error(exp.loc,
                "missing type hint for array or record initializer")
        end

        if type_hint._tag == "types.T.Array" then
            for _, field in ipairs(exp.fields) do
                if field.name then
                    type_error(field.loc,
                        "named field %s in array initializer",
                        field.name)
                end
                local field_type = type_hint.elem
                check_exp(field.exp, field_type)
                check_match(field.loc,
                    field_type, field.exp._type,
                    "array initializer")
            end

        elseif type_hint._tag == "types.T.Record" then
            local initialized_fields = {}
            for _, field in ipairs(exp.fields) do
                if not field.name then
                    type_error(field.loc,
                        "record initializer has array part")
                end

                if initialized_fields[field.name] then
                    type_error(field.loc,
                        "duplicate field %s in record initializer",
                        field.name)
                end
                initialized_fields[field.name] = true

                local field_type = type_hint.field_types[field.name]
                if field_type then
                    check_exp(field.exp, field_type)
                    check_match(field.loc,
                        field_type, field.exp._type,
                        "record initializer")
                else
                    type_error(field.loc,
                        "invalid field %s in record initializer for %s",
                        field.name, types.tostring(type_hint))
                end
            end

            for field_name, _ in pairs(type_hint.field_types) do
                if not initialized_fields[field_name] then
                    type_error(exp.loc,
                        "required field %s is missing from initializer",
                        field_name)
                end
            end
        else
            type_error(exp.loc,
                "type hint for array or record initializer is not an array or record type")
        end
        exp._type = type_hint

    elseif tag == "ast.Exp.Var" then
        check_var(exp.var)
        exp._type = exp.var._type

    elseif tag == "ast.Exp.Unop" then
        check_exp(exp.exp, false)
        local op = exp.op
        if op == "#" then
            if exp.exp._type._tag ~= "types.T.Array" and exp.exp._type._tag ~= "types.T.String" then
                type_error(exp.loc,
                    "trying to take the length of a %s instead of an array or string",
                    types.tostring(exp.exp._type))
            end
            exp._type = types.T.Integer()
        elseif op == "-" then
            if exp.exp._type._tag ~= "types.T.Integer" and exp.exp._type._tag ~= "types.T.Float" then
                type_error(exp.loc,
                    "trying to negate a %s instead of a number",
                    types.tostring(exp.exp._type))
            end
            exp._type = exp.exp._type
        elseif op == "~" then
            if exp.exp._type._tag ~= "types.T.Integer" then
                type_error(exp.loc,
                    "trying to bitwise negate a %s instead of an integer",
                    types.tostring(exp.exp._type))
            end
            exp._type = types.T.Integer()
        elseif op == "not" then
            if exp.exp._type._tag ~= "types.T.Boolean" then
                -- We are being intentionaly restrictive here w.r.t Lua
                type_error(exp.loc,
                    "trying to boolean negate a %s instead of a boolean",
                    types.tostring(exp.exp._type))
            end
            exp._type = types.T.Boolean()
        else
            error("impossible")
        end

    elseif tag == "ast.Exp.Concat" then
        for _, inner_exp in ipairs(exp.exps) do
            check_exp(inner_exp, false)
            local t_exp = inner_exp._type
            if t_exp._tag ~= "types.T.String" then
                type_error(inner_exp.loc,
                    "cannot concatenate with %s value", types.tostring(t_exp))
            end
        end
        exp._type = types.T.String()

    elseif tag == "ast.Exp.Binop" then
        check_exp(exp.lhs, false)
        check_exp(exp.rhs, false)
        local op = exp.op
        if op == "==" or op == "~=" then
            if (exp.lhs._type._tag == "types.T.Integer" and exp.rhs._type._tag == "types.T.Float") or
               (exp.lhs._type._tag == "types.T.Float"   and exp.rhs._type._tag == "types.T.Integer") then
                type_error(exp.loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
            end
            if not types.equals(exp.lhs._type, exp.rhs._type) then
                type_error(exp.loc,
                    "cannot compare %s and %s using %s",
                    types.tostring(exp.lhs._type), types.tostring(exp.rhs._type), op)
            end
            exp._type = types.T.Boolean()
        elseif op == "<" or op == ">" or op == "<=" or op == ">=" then
            if (exp.lhs._type._tag == "types.T.Integer" and exp.rhs._type._tag == "types.T.Integer") or
               (exp.lhs._type._tag == "types.T.Float"   and exp.rhs._type._tag == "types.T.Float") or
               (exp.lhs._type._tag == "types.T.String"  and exp.rhs._type._tag == "types.T.String") then
               -- OK
            elseif (exp.lhs._type._tag == "types.T.Integer" and exp.rhs._type._tag == "types.T.Float") or
                   (exp.lhs._type._tag == "types.T.Float"   and exp.rhs._type._tag == "types.T.Integer") then
                type_error(exp.loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
            else
                type_error(exp.loc,
                    "cannot compare %s and %s using %s",
                    types.tostring(exp.lhs._type), types.tostring(exp.rhs._type), op)
            end
            exp._type = types.T.Boolean()

        elseif op == "+" or op == "-" or op == "*" or op == "%" or op == "//" then
            if not is_numeric_type(exp.lhs._type) then
                type_error(exp.loc,
                    "left hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(exp.lhs._type))
            end
            if not is_numeric_type(exp.rhs._type) then
                type_error(exp.loc,
                    "right hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(exp.rhs._type))
            end

            if exp.lhs._type._tag == "types.T.Integer" and
               exp.rhs._type._tag == "types.T.Integer" then
                exp._type = types.T.Integer()
            else
                exp.lhs = coerce_numeric_exp_to_float(exp.lhs)
                exp.rhs = coerce_numeric_exp_to_float(exp.rhs)
                exp._type = types.T.Float()
            end

        elseif op == "/" or op == "^" then
            if not is_numeric_type(exp.lhs._type) then
                type_error(exp.loc,
                    "left hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(exp.lhs._type))
            end
            if not is_numeric_type(exp.rhs._type) then
                type_error(exp.loc,
                    "right hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(exp.rhs._type))
            end

            exp.lhs = coerce_numeric_exp_to_float(exp.lhs)
            exp.rhs = coerce_numeric_exp_to_float(exp.rhs)
            exp._type = types.T.Float()

        elseif op == "and" or op == "or" then
            if exp.lhs._type._tag ~= "types.T.Boolean" then
                type_error(exp.loc,
                    "left hand side of logical expression is a %s instead of a boolean",
                    types.tostring(exp.lhs._type))
            end
            if exp.rhs._type._tag ~= "types.T.Boolean" then
                type_error(exp.loc,
                    "right hand side of logical expression is a %s instead of a boolean",
                    types.tostring(exp.rhs._type))
            end
            exp._type = types.T.Boolean()
        elseif op == "|" or op == "&" or op == "~" or op == "<<" or op == ">>" then
            if exp.lhs._type._tag ~= "types.T.Integer" then
                type_error(exp.loc,
                    "left hand side of bitwise expression is a %s instead of an integer",
                    types.tostring(exp.lhs._type))
            end
            if exp.rhs._type._tag ~= "types.T.Integer" then
                type_error(exp.loc,
                    "right hand side of bitwise expression is a %s instead of an integer",
                    types.tostring(exp.rhs._type))
            end
            exp._type = types.T.Integer()
        else
            error("impossible")
        end

    elseif tag == "ast.Exp.CallFunc" then
        local f_exp = exp.exp
        local args = exp.args

        check_exp(f_exp, false)
        local f_type = f_exp._type

        if f_type._tag == "types.T.Function" then
            if #f_type.params ~= #args then
                type_error(exp.loc,
                    "function expects %d argument(s) but received %d",
                    #f_type.params, #args)
            end
            for i = 1, math.min(#f_type.params, #args) do
                local p_type = f_type.params[i]
                local arg = args[i]
                check_exp(arg, p_type)
                args[i] = try_coerce(arg, p_type,
                    "argument %d of call to function", i)
            end
            assert(#f_type.ret_types <= 1)
            if #f_type.ret_types >= 1 then
                exp._type = f_type.ret_types[1]
            else
                exp._type = types.T.Void()
            end
        else
            type_error(exp.loc,
                "attempting to call a %s value",
                types.tostring(exp.exp._type))
        end

    elseif tag == "ast.Exp.CallMethod" then
        error("not implemented")

    elseif tag == "ast.Exp.Cast" then
        local target = check_type(exp.target)
        check_exp(exp.exp, target)
        if not types.consistent(exp.exp._type, target) then
            type_error(exp.loc,
                "cannot cast %s to %s",
                types.tostring(exp.exp._type), types.tostring(target))
        end
        exp._type = target

    else
        error("impossible")
    end
end

return checker
