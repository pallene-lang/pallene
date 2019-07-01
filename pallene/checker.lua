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
local check_var
local check_exp_synthesize
local check_exp_verify

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

local function is_numeric_type(typ)
    return typ._tag == "types.T.Integer" or typ._tag == "types.T.Float"
end

local function coerce_numeric_exp_to_float(exp)
    if exp._type._tag == "types.T.Integer" then
        local name = ast.Var.Name(false, "tofloat")
        name._decl = builtins.tofloat
        local tofloat = ast.Exp.Var(false, name)
        local call = ast.Exp.CallFunc(false, tofloat, {exp})
        check_exp_synthesize(call)
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
            tl_node.value = check_exp_verify(tl_node.value, tl_node._type,
                "declaration of module variable %s", tl_node.decl.name)
        else
            check_exp_synthesize(tl_node.value)
        end
        tl_node._type = tl_node.value._type

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
            stat.exp = check_exp_verify(stat.exp, stat.decl._type,
                "declaration of local variable %s", stat.decl.name)
        else
            check_exp_synthesize(stat.exp)
            stat.decl._type = stat.exp._type
            check_decl(stat.decl)
        end

    elseif tag == "ast.Stat.Block" then
        for _, inner_stat in ipairs(stat.stats) do
            check_stat(inner_stat, ret_types)
        end

    elseif tag == "ast.Stat.While" then
        stat.condition = check_exp_verify(
            stat.condition, types.T.Boolean(),
            "while loop condition")
        check_stat(stat.block, ret_types)

    elseif tag == "ast.Stat.Repeat" then
        for _, inner_stat in ipairs(stat.block.stats) do
            check_stat(inner_stat, ret_types)
        end
        stat.condition = check_exp_verify(
            stat.condition, types.T.Boolean(),
            "repeat-until loop condition")

    elseif tag == "ast.Stat.For" then

        if stat.decl.type then
            check_decl(stat.decl)
            stat.start = check_exp_verify(stat.start, stat.decl._type,
                "numeric for-loop initializer")
        else
            check_exp_synthesize(stat.start)
            stat.decl._type = stat.start._type
        end
        local loop_type = stat.decl._type

        if  loop_type._tag ~= "types.T.Integer" and
            loop_type._tag ~= "types.T.Float"
        then
            type_error(stat.decl.loc,
                "expected integer or float but found %s in for-loop control variable '%s'",
                types.tostring(loop_type),
                stat.decl.name)
        end

        stat.limit = check_exp_verify(stat.limit, loop_type,
            "numeric for-loop limit")

        if stat.step then
            stat.step = check_exp_verify(stat.step, loop_type,
                "numeric for-loop step")
        else
            if  loop_type._tag == "types.T.Integer" then
                stat.step = ast.Exp.Integer(stat.limit.loc, 1)
            elseif loop_type._tag == "types.T.Float" then
                stat.step = ast.Exp.Float(stat.limit.loc, 1.0)
            else
                error("impossible")
            end
            check_exp_synthesize(stat.step)
        end

        check_stat(stat.block, ret_types)

    elseif tag == "ast.Stat.Assign" then
        check_var(stat.var)
        stat.exp = check_exp_verify(stat.exp, stat.var._type, "assignment")
        if stat.var._tag == "ast.Var.Name" and
            stat.var._decl._tag == "ast.Toplevel.Func"
        then
            type_error(stat.loc,
                "attempting to assign to toplevel constant function %s",
                stat.var.name)
        end

    elseif tag == "ast.Stat.Call" then
        check_exp_synthesize(stat.call_exp)

    elseif tag == "ast.Stat.Return" then
        assert(#ret_types <= 1)
        if #stat.exps ~= #ret_types then
            type_error(stat.loc,
                "returning %d value(s) but function expects %s",
                #stat.exps, #ret_types)
        end

        for i = 1, #stat.exps do
            stat.exps[i] = check_exp_verify(
                stat.exps[i], ret_types[i],
                "return statement")
        end

    elseif tag == "ast.Stat.If" then
        stat.condition = check_exp_verify(
            stat.condition, types.T.Boolean(),
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
        check_exp_synthesize(var.exp)
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
        check_exp_synthesize(var.t)
        local arr_type = var.t._type
        if arr_type._tag ~= "types.T.Array" then
            type_error(var.t.loc,
                "expected array but found %s in array indexing",
                types.tostring(arr_type))
        end
        var.k = check_exp_verify(
            var.k, types.T.Integer(),
            "array indexing")
        var._type = var.t._type.elem

    else
        error("impossible")
    end
end

-- Infers the type of expression @exp
-- Returns nothing
check_exp_synthesize = function(exp)
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
        type_error(exp.loc,
            "missing type hint for array or record initializer")

    elseif tag == "ast.Exp.Var" then
        check_var(exp.var)
        exp._type = exp.var._type

    elseif tag == "ast.Exp.Unop" then
        check_exp_synthesize(exp.exp)
        local t = exp.exp._type
        local op = exp.op
        if op == "#" then
            if t._tag ~= "types.T.Array" and t._tag ~= "types.T.String" then
                type_error(exp.loc,
                    "trying to take the length of a %s instead of an array or string",
                    types.tostring(t))
            end
            exp._type = types.T.Integer()
        elseif op == "-" then
            if t._tag ~= "types.T.Integer" and t._tag ~= "types.T.Float" then
                type_error(exp.loc,
                    "trying to negate a %s instead of a number",
                    types.tostring(t))
            end
            exp._type = t
        elseif op == "~" then
            if t._tag ~= "types.T.Integer" then
                type_error(exp.loc,
                    "trying to bitwise negate a %s instead of an integer",
                    types.tostring(t))
            end
            exp._type = types.T.Integer()
        elseif op == "not" then
            if t._tag ~= "types.T.Boolean" then
                -- We are being intentionaly restrictive here w.r.t Lua
                type_error(exp.loc,
                    "trying to boolean negate a %s instead of a boolean",
                    types.tostring(t))
            end
            exp._type = types.T.Boolean()
        else
            error("impossible")
        end

    elseif tag == "ast.Exp.Concat" then
        for _, inner_exp in ipairs(exp.exps) do
            check_exp_synthesize(inner_exp)
            local t = inner_exp._type
            if t._tag ~= "types.T.String" then
                type_error(inner_exp.loc,
                    "cannot concatenate with %s value", types.tostring(t))
            end
        end
        exp._type = types.T.String()

    elseif tag == "ast.Exp.Binop" then
        check_exp_synthesize(exp.lhs); local t1 = exp.lhs._type
        check_exp_synthesize(exp.rhs); local t2 = exp.rhs._type
        local op = exp.op
        if op == "==" or op == "~=" then
            if (t1._tag == "types.T.Integer" and t2._tag == "types.T.Float") or
               (t1._tag == "types.T.Float"   and t2._tag == "types.T.Integer") then
                type_error(exp.loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
            end
            if not types.equals(t1, t2) then
                type_error(exp.loc,
                    "cannot compare %s and %s using %s",
                    types.tostring(t1), types.tostring(t2), op)
            end
            exp._type = types.T.Boolean()

        elseif op == "<" or op == ">" or op == "<=" or op == ">=" then
            if (t1._tag == "types.T.Integer" and t2._tag == "types.T.Integer") or
               (t1._tag == "types.T.Float"   and t2._tag == "types.T.Float") or
               (t1._tag == "types.T.String"  and t2._tag == "types.T.String") then
               -- OK
            elseif (t1._tag == "types.T.Integer" and t2._tag == "types.T.Float") or
                   (t1._tag == "types.T.Float"   and t2._tag == "types.T.Integer") then
                -- note: use Lua's implementation of comparison, don't just cast to float
                type_error(exp.loc,
                    "comparisons between float and integers are not yet implemented")
            else
                type_error(exp.loc,
                    "cannot compare %s and %s using %s",
                    types.tostring(t1), types.tostring(t2), op)
            end
            exp._type = types.T.Boolean()

        elseif op == "+" or op == "-" or op == "*" or op == "%" or op == "//" then
            if not is_numeric_type(t1) then
                type_error(exp.loc,
                    "left hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(t1))
            end
            if not is_numeric_type(t2) then
                type_error(exp.loc,
                    "right hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(t2))
            end

            if t1._tag == "types.T.Integer" and
               t2._tag == "types.T.Integer"
            then
                exp._type = types.T.Integer()
            else
                exp.lhs = coerce_numeric_exp_to_float(exp.lhs)
                exp.rhs = coerce_numeric_exp_to_float(exp.rhs)
                exp._type = types.T.Float()
            end

        elseif op == "/" or op == "^" then
            if not is_numeric_type(t1) then
                type_error(exp.loc,
                    "left hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(t1))
            end
            if not is_numeric_type(t2) then
                type_error(exp.loc,
                    "right hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(t2))
            end

            exp.lhs = coerce_numeric_exp_to_float(exp.lhs)
            exp.rhs = coerce_numeric_exp_to_float(exp.rhs)
            exp._type = types.T.Float()

        elseif op == "and" or op == "or" then
            if t1._tag ~= "types.T.Boolean" then
                type_error(exp.loc,
                    "left hand side of logical expression is a %s instead of a boolean",
                    types.tostring(t1))
            end
            if t2._tag ~= "types.T.Boolean" then
                type_error(exp.loc,
                    "right hand side of logical expression is a %s instead of a boolean",
                    types.tostring(t2))
            end
            exp._type = types.T.Boolean()

        elseif op == "|" or op == "&" or op == "~" or op == "<<" or op == ">>" then
            if t1._tag ~= "types.T.Integer" then
                type_error(exp.loc,
                    "left hand side of bitwise expression is a %s instead of an integer",
                    types.tostring(t1))
            end
            if t2._tag ~= "types.T.Integer" then
                type_error(exp.loc,
                    "right hand side of bitwise expression is a %s instead of an integer",
                    types.tostring(t2))
            end
            exp._type = types.T.Integer()

        else
            error("impossible")
        end

    elseif tag == "ast.Exp.CallFunc" then
        local f_exp = exp.exp
        local args = exp.args

        check_exp_synthesize(f_exp)
        local f_type = f_exp._type

        if f_type._tag == "types.T.Function" then
            if #f_type.params ~= #args then
                type_error(exp.loc,
                    "function expects %d argument(s) but received %d",
                    #f_type.params, #args)
            end
            for i = 1, math.min(#f_type.params, #args) do
                args[i] = check_exp_verify(args[i], f_type.params[i],
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
        local dst_t = check_type(exp.target)
        check_exp_synthesize(exp.exp)
        local src_t = exp.exp._type
        if not types.consistent(src_t, dst_t) then
            type_error(exp.loc,
                "cannot cast %s to %s",
                types.tostring(src_t), types.tostring(dst_t))
        end
        exp._type = dst_t

    else
        error("impossible")
    end
end

-- Verifies that expression @exp has type expected_type.
-- Returnsthe typechecked expression. This may be either be the original
-- expression, or a coersion node from the original expression to the expected
-- type.
--
-- errmsg_fmt: format string describing what part of the program is
--             responsible for this type check
-- ...: arguments to the "errmsg_fmt" format string
check_exp_verify = function(exp, expected_type, errmsg_fmt, ...)
    local tag = exp._tag

    if tag == "ast.Exp.Initlist" then

        if expected_type._tag == "types.T.Array" then
            for _, field in ipairs(exp.fields) do
                if field.name then
                    type_error(field.loc,
                        "named field %s in array initializer",
                        field.name)
                end
                field.exp = check_exp_verify(
                    field.exp, expected_type.elem,
                    "array initializer")
            end

        elseif expected_type._tag == "types.T.Record" then
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

                local field_type = expected_type.field_types[field.name]
                if not field_type then
                    type_error(field.loc,
                        "invalid field %s in record initializer for %s",
                        field.name, types.tostring(expected_type))
                end

                field.exp = check_exp_verify(
                    field.exp, field_type,
                    "record initializer")
            end

            for field_name, _ in pairs(expected_type.field_types) do
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

        exp._type = expected_type
        return exp

    else

        check_exp_synthesize(exp)
        local found_type = exp._type

        if types.equals(found_type, expected_type) then
            return exp
        elseif types.consistent(found_type, expected_type) then
            local cast = ast.Exp.Cast(exp.loc, exp, false)
            cast._type = expected_type
            return cast
        else
            type_error(exp.loc, string.format(
                "expected %s but found %s in %s",
                types.tostring(expected_type),
                types.tostring(found_type),
                string.format(errmsg_fmt, ...)))
        end
    end
end

return checker
