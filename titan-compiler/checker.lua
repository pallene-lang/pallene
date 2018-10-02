local checker = {}

local ast = require "titan-compiler.ast"
local builtins = require "titan-compiler.builtins"
local location = require "titan-compiler.location"
local types = require "titan-compiler.types"

local typecheck

local check_program
local check_type
local check_toplevel
local check_decl
local check_stat
--local check_then
local check_var
local check_exp
--local check_field

-- Type-check a Titan module
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
-- @ param prog AST for the whole module
-- @ return true or false, followed by as list of compilation errors
function checker.check(prog)
    return typecheck(prog)
end

--
-- local functions
--

local TypeError = {}
TypeError.__index = TypeError

function TypeError.new(msg)
    return setmetatable({ msg = msg }, TypeError)
end

local function type_error(loc, fmt, ...)
    local errmsg = location.format_error(loc, "type error: "..fmt, ...)
    error(TypeError.new(errmsg))
end

-- Checks if two types are the same, and logs an error message otherwise
--   loc: location of the term that is being compared
--   expected: type that is expected
--   found: type that was actually present
--   termfmt: format string describing what is being compared
--   ...: arguments to the "term" format string
local function checkmatch(loc, expected, found, termfmt, ...)
    if not types.equals(expected, found) then
        local term = string.format(termfmt, ...)
        local expected_str = types.tostring(expected)
        local found_str = types.tostring(found)
        local msg = string.format(
            "types in %s do not match, expected %s but found %s",
            term, expected_str, found_str)
        type_error(loc, msg)
    end
end

local function check_arity(loc, expected, found, termfmt, ...)
    if expected ~= found then
        local term = string.format(termfmt, ...)
        local msg = string.format("%s: expected %d value(s) but found %d",
            term, expected, found)
        type_error(loc, msg)
    end
end

local function check_is_array(loc, found, termfmt, ...)
    if found._tag ~= types.T.Array then
        local term = string.format(termfmt, ...)
        local found_str = types.tostring(found)
        local msg = string.format("%s: expected array but found %s",
            term, found_str)
        type_error(loc, msg)
    end
end

local function is_numeric_type(typ)
    return typ._tag == types.T.Integer or typ._tag == types.T.Float
end

local function coerce_numeric_exp_to_float(exp)
    if exp._type._tag == types.T.Integer then
        local n = ast.Exp.Cast(exp.loc, exp, nil)
        n._type = types.T.Float()
        return n
    elseif exp._type._tag == types.T.Float then
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
    if     tag  == ast.Stat.Decl then
        return false
    elseif tag == ast.Stat.Block then
        for _, inner_stat in ipairs(stat.stats) do
            if stat_always_returns(inner_stat) then
                return true
            end
        end
        return false
    elseif tag == ast.Stat.While then
        return false
    elseif tag == ast.Stat.Repeat then
        return false
    elseif tag == ast.Stat.For then
        return false
    elseif tag == ast.Stat.Assign then
        return false
    elseif tag == ast.Stat.Call  then
        return false
    elseif tag == ast.Stat.Return then
        return true
    elseif tag == ast.Stat.If then
        return stat_always_returns(stat.then_) and
                stat_always_returns(stat.else_)
    else
        error("impossible")
    end
end

--
-- check
--

typecheck = function(prog)
    local ok, err = xpcall(check_program, debug.traceback, prog)
    if ok then
        return prog, {} -- TODO:  no {}
    else
        if getmetatable(err) == TypeError then
            return false, { err.msg } -- TODO  no {}
        else
            error(err)
        end
    end
end

check_program = function(prog)
    -- Ugh!
    -- Here we mutate fields in "constant" variables from another module, which
    -- definitely smells bad. There are many ways we vould fix this but I don't
    -- know which one would be best:
    -- * Have the builtins module fill in the _type field once and forall
    -- * Have `type` be a local table mapping decls to types instead of a field
    --   we set in the decl.
    -- * Modify the AST in a previous step, replacing CallFunc nodes with
    --   CallBuiltin nodes. This would avoid needing to type builtin functions
    --   in the first place.
    for _, decl in pairs(builtins) do
        decl._type = types.T.Builtin(decl)
    end

    for _, tlnode in ipairs(prog) do
        check_toplevel(tlnode)
    end
end

check_type = function(typ)
    local tag = typ._tag
    if     tag == ast.Type.Nil then
        return types.T.Nil()

    elseif tag == ast.Type.Boolean then
        return types.T.Boolean()

    elseif tag == ast.Type.Integer then
        return types.T.Integer()

    elseif tag == ast.Type.Float then
        return types.T.Float()

    elseif tag == ast.Type.String then
        return types.T.String()

    elseif tag == ast.Type.Name then
        local decl = typ._decl
        if decl._tag == ast.Toplevel.Record then
            return assert(decl._type)
        else
            type_error(typ.loc, "'%s' isn't a type", typ.name)
        end

    elseif tag == ast.Type.Array then
        local subtype = check_type(typ.subtype)
        if subtype._tag == types.T.Nil then
            type_error(typ.loc, "array of nil is not allowed")
        end
        return types.T.Array(subtype)

    elseif tag == ast.Type.Function then
        if #typ.rettypes >= 2 then
            error("functions with 2+ return values are not yet implemented")
        end
        local ptypes = {}
        for _, ptype in ipairs(typ.argtypes) do
            table.insert(ptypes, check_type(ptype))
        end
        local rettypes = {}
        for _, rettype in ipairs(typ.rettypes) do
            table.insert(rettypes, check_type(rettype))
        end
        return types.T.Function(ptypes, rettypes)

    else
        error("impossible")
    end
end

check_toplevel = function(tl_node)
    local tag = tl_node._tag
    if     tag == ast.Toplevel.Import then
        type_error(tl_node.loc, "modules are not implemented yet")

    elseif tag == ast.Toplevel.Var then
        if tl_node.decl.type then
            tl_node._type = check_type(tl_node.decl.type)
            check_exp(tl_node.value, tl_node._type)
            checkmatch(tl_node.loc,
                tl_node._type, tl_node.value._type,
                "declaration of module variable %s", tl_node.decl.name)
        else
            check_exp(tl_node.value, false)
            tl_node._type = tl_node.value._type
        end

    elseif tag == ast.Toplevel.Func then
        if #tl_node.rettypes >= 2 then
            error("functions with 2+ return values are not yet implemented")
        end

        local ptypes = {}
        for _, param in ipairs(tl_node.params) do
            param._type = check_type(param.type)
            table.insert(ptypes, param._type)
        end

        local rettypes = {}
        for _, rt in ipairs(tl_node.rettypes) do
            table.insert(rettypes, check_type(rt))
        end
        tl_node._type = types.T.Function(ptypes, rettypes)

        check_stat(tl_node.block, rettypes)

        if #tl_node._type.rettypes > 0 and
           not stat_always_returns(tl_node.block)
        then
            type_error(tl_node.loc,
                "control reaches end of function with non-empty return type")
        end

    elseif tag == ast.Toplevel.Record then
        tl_node._field_types = {}
        for _, field_decl in ipairs(tl_node.field_decls) do
            local typ = check_type(field_decl.type)
            tl_node._field_types[field_decl.name] = typ
        end
        tl_node._type = types.T.Record(tl_node)

    else
        error("impossible")
    end
end

check_decl = function(decl)
    decl._type = decl._type or check_type(decl.type)
end

-- @param rettypes Declared function return types (for return statements)
check_stat = function(stat, rettypes)
    local tag = stat._tag
    if     tag == ast.Stat.Decl then
        if stat.decl.type then
            check_decl(stat.decl)
            check_exp(stat.exp, stat.decl._type)
        else
            check_exp(stat.exp, false)
            stat.decl._type = stat.exp._type
            check_decl(stat.decl)
        end
        checkmatch(stat.decl.loc,
            stat.decl._type, stat.exp._type,
            "declaration of local variable %s", stat.decl.name)

    elseif tag == ast.Stat.Block then
        for _, inner_stat in ipairs(stat.stats) do
            check_stat(inner_stat, rettypes)
        end

    elseif tag == ast.Stat.While then
        check_exp(stat.condition, false)
        checkmatch(stat.condition.loc,
            types.T.Boolean(), stat.condition._type,
            "while statement condition")
        check_stat(stat.block, rettypes)

    elseif tag == ast.Stat.Repeat then
        for _, inner_stat in ipairs(stat.block.stats) do
            check_stat(inner_stat, rettypes)
        end
        check_exp(stat.condition, false)
        checkmatch(stat.condition.loc,
            types.T.Boolean(), stat.condition._type,
            "repeat statement condition")

    elseif tag == ast.Stat.For then
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

        if     stat.decl._type._tag == types.T.Integer then
            if not stat.step then
                stat.step = ast.Exp.Integer(stat.limit.loc, 1)
                stat.step._type = types.T.Integer()
            end
        elseif stat.decl._type._tag == types.T.Float then
            if not stat.step then
                stat.step = ast.Exp.Float(stat.limit.loc, 1.0)
                stat.step._type = types.T.Float()
            end
        else
            type_error(stat.decl.loc,
                "type of for control variable %s must be integer or float",
                stat.decl.name)
        end

        checkmatch(stat.start.loc,
            stat.decl._type, stat.start._type,
            "numeric for loop initializer")

        checkmatch(stat.limit.loc,
            stat.decl._type, stat.limit._type,
            "numeric for loop limit")

        checkmatch(stat.step.loc,
            stat.decl._type, stat.step._type,
            "numeric for loop step")

        check_stat(stat.block, rettypes)

    elseif tag == ast.Stat.Assign then
        check_var(stat.var)
        check_exp(stat.exp, stat.var._type)
        checkmatch(stat.var.loc,
            stat.var._type, stat.exp._type,
            "assignment")
        if stat.var._tag == ast.Var.Name and
            stat.var._decl._tag == ast.Toplevel.Func
        then
            type_error(stat.loc,
                "attempting to assign to toplevel constant function %s",
                stat.var.name)
        end

    elseif tag == ast.Stat.Call then
        check_exp(stat.callexp, false)

    elseif tag == ast.Stat.Return then
        assert(#rettypes <= 1)
        if #stat.exps ~= #rettypes then
            type_error(stat.loc,
                "returning %d value(s) but function expects %s",
                #stat.exps, #rettypes)
        end

        for i = 1, #stat.exps do
            local exp = stat.exps[i]
            local rettype = rettypes[i]
            check_exp(exp, rettype)
            checkmatch(exp.loc,
                rettype, exp._type,
                "return statement")
        end

    elseif tag == ast.Stat.If then
        local cond = stat.condition
        check_exp(cond, false)
        checkmatch(cond.loc,
            types.T.Boolean(), cond._type,
            "if statement condition")

        check_stat(stat.then_, rettypes)
        check_stat(stat.else_, rettypes)

    else
        error("impossible")
    end
end

check_var = function(var)
    local tag = var._tag
    if     tag == ast.Var.Name then
        local decl = var._decl
        if decl._tag == ast.Toplevel.Var or
            decl._tag == ast.Toplevel.Func or
            decl._tag == ast.Toplevel.Builtin or
            decl._tag == ast.Decl.Decl
        then
            var._type = var._decl._type
        else
            type_error(var.loc, "'%s' isn't a value", var.name)
        end

    elseif tag == ast.Var.Dot then
        check_exp(var.exp, false)
        local exptype = var.exp._type
        if exptype._tag == types.T.Record then
            local field_type = exptype.type_decl._field_types[var.name]
            if field_type then
                var._type = field_type
            else
                type_error(var.loc,
                    "field '%s' not found in record '%s'",
                    var.name, exptype.type_decl.name)
            end
        else
            type_error(var.loc,
                "trying to access a member of value of type '%s'",
                types.tostring(exptype))
        end

    elseif tag == ast.Var.Bracket then
        check_exp(var.exp1, false)
        if var.exp1._type._tag ~= types.T.Array then
            type_error(var.exp1.loc,
                "array expression in indexing is not an array but %s",
                types.tostring(var.exp1._type))
        end
        var._type = var.exp1._type.elem
        check_exp(var.exp2, false)
        checkmatch(var.exp2.loc,
            types.T.Integer(), var.exp2._type,
            "array indexing")

    else
        error("impossible")
    end
end

local function check_exp_callfunc_builtin(exp, _typehint)
    assert(_typehint ~= nil)

    local fexp = exp.exp
    local args = exp.args
    local builtin_name = fexp._type.builtin_decl.name
    if builtin_name == "io.write" then
        check_arity(exp.loc, 1, #args, "io.write arguments")
        check_exp(args[1], false)
        checkmatch(args[1].loc,
            types.T.String(), args[1]._type,
            "io.write argument")
        exp._type = types.T.Void()
    elseif builtin_name == "table.insert" then
        check_arity(exp.loc, 2, #args, "table.insert arguments")
        check_exp(args[1], false)
        check_is_array(
            args[1].loc, args[1]._type, "table.insert first argument")
        local elem_type = args[1]._type.elem
        check_exp(args[2], elem_type)
        checkmatch(args[2].loc,
            elem_type, args[2]._type,
            "table.insert second argument")
        exp._type = types.T.Void()
    elseif builtin_name == "table.remove" then
        check_arity(exp.loc, 1, #args, "table.insert arguments")
        check_exp(args[1], false)
        check_is_array(
            args[1].loc, args[1]._type, "table.insert first argument")
        exp._type = types.T.Void()
    else
        error("impossible")
    end
end

-- @param typehint Expected type; Used to infer polymorphic/record constructors.
check_exp = function(exp, typehint)
    assert(typehint ~= nil)

    local tag = exp._tag
    if     tag == ast.Exp.Nil then
        exp._type = types.T.Nil()

    elseif tag == ast.Exp.Bool then
        exp._type = types.T.Boolean()

    elseif tag == ast.Exp.Integer then
        exp._type = types.T.Integer()

    elseif tag == ast.Exp.Float then
        exp._type = types.T.Float()

    elseif tag == ast.Exp.String then
        exp._type = types.T.String()

    elseif tag == ast.Exp.Initlist then
        -- Determining the type for a table initializer *requires* a type hint.
        -- In theory, we could try to infer the type without a type hint for
        -- non-empty arrays whose contents are inferrable, but I am not sure
        -- we should treat that case differently from the others...
        --
        if not typehint then
            type_error(exp.loc,
                "missing type hint for array or record initializer")
        end

        if typehint._tag == types.T.Array then
            for _, field in ipairs(exp.fields) do
                if field.name then
                    type_error(field.loc,
                        "named field %s in array initializer",
                        field.name)
                end
                local field_type = typehint.elem
                check_exp(field.exp, field_type)
                checkmatch(field.loc,
                    field_type, field.exp._type,
                    "array initializer")
            end

        elseif typehint._tag == types.T.Record then
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

                local field_type = typehint.type_decl._field_types[field.name]
                if field_type then
                    check_exp(field.exp, field_type)
                    checkmatch(field.loc,
                        field_type, field.exp._type,
                        "record initializer")
                else
                    type_error(field.loc,
                        "invalid field %s in record initializer for %s",
                        field.name, typehint.type_decl.name)
                end
            end

            for field_name, _ in pairs(typehint.type_decl._field_types) do
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
        exp._type = typehint

    elseif tag == ast.Exp.Var then
        check_var(exp.var)
        exp._type = exp.var._type

    elseif tag == ast.Exp.Unop then
        check_exp(exp.exp, false)
        local op = exp.op
        if op == "#" then
            if exp.exp._type._tag ~= types.T.Array and exp.exp._type._tag ~= types.T.String then
                type_error(exp.loc,
                    "trying to take the length of a %s instead of an array or string",
                    types.tostring(exp.exp._type))
            end
            exp._type = types.T.Integer()
        elseif op == "-" then
            if exp.exp._type._tag ~= types.T.Integer and exp.exp._type._tag ~= types.T.Float then
                type_error(exp.loc,
                    "trying to negate a %s instead of a number",
                    types.tostring(exp.exp._type))
            end
            exp._type = exp.exp._type
        elseif op == "~" then
            if exp.exp._type._tag ~= types.T.Integer then
                type_error(exp.loc,
                    "trying to bitwise negate a %s instead of an integer",
                    types.tostring(exp.exp._type))
            end
            exp._type = types.T.Integer()
        elseif op == "not" then
            if exp.exp._type._tag ~= types.T.Boolean then
                -- We are being intentionaly restrictive here w.r.t Lua
                type_error(exp.loc,
                    "trying to boolean negate a %s instead of a boolean",
                    types.tostring(exp.exp._type))
            end
            exp._type = types.T.Boolean()
        else
            error("impossible")
        end

    elseif tag == ast.Exp.Concat then
        for _, inner_exp in ipairs(exp.exps) do
            check_exp(inner_exp, false)
            local texp = inner_exp._type
            if texp._tag ~= types.T.String then
                type_error(inner_exp.loc,
                    "cannot concatenate with %s value", types.tostring(texp))
            end
        end
        exp._type = types.T.String()

    elseif tag == ast.Exp.Binop then
        check_exp(exp.lhs, false)
        check_exp(exp.rhs, false)
        local op = exp.op
        if op == "==" or op == "~=" then
            if (exp.lhs._type._tag == types.T.Integer and exp.rhs._type._tag == types.T.Float) or
               (exp.lhs._type._tag == types.T.Float   and exp.rhs._type._tag == types.T.Integer) then
                type_error(exp.loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
            end
            if not types.equals(exp.lhs._type, exp.rhs._type) then
                type_error(exp.loc,
                    "cannot compare %s and %s with %s",
                    types.tostring(exp.lhs._type), types.tostring(exp.rhs._type), op)
            end
            exp._type = types.T.Boolean()
        elseif op == "<" or op == ">" or op == "<=" or op == ">=" then
            if (exp.lhs._type._tag == types.T.Integer and exp.rhs._type._tag == types.T.Integer) or
               (exp.lhs._type._tag == types.T.Float   and exp.rhs._type._tag == types.T.Float) or
               (exp.lhs._type._tag == types.T.String  and exp.rhs._type._tag == types.T.String) then
               -- OK
            elseif (exp.lhs._type._tag == types.T.Integer and exp.rhs._type._tag == types.T.Float) or
                   (exp.lhs._type._tag == types.T.Float   and exp.rhs._type._tag == types.T.Integer) then
                type_error(exp.loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
            else
                type_error(exp.loc,
                    "cannot compare %s and %s with %s",
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

            if exp.lhs._type._tag == types.T.Integer and
               exp.rhs._type._tag == types.T.Integer then
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
            if exp.lhs._type._tag ~= types.T.Boolean then
                type_error(exp.loc,
                    "left hand side of logical expression is a %s instead of a boolean",
                    types.tostring(exp.lhs._type))
            end
            if exp.rhs._type._tag ~= types.T.Boolean then
                type_error(exp.loc,
                    "right hand side of logical expression is a %s instead of a boolean",
                    types.tostring(exp.rhs._type))
            end
            exp._type = types.T.Boolean()
        elseif op == "|" or op == "&" or op == "~" or op == "<<" or op == ">>" then
            if exp.lhs._type._tag ~= types.T.Integer then
                type_error(exp.loc,
                    "left hand side of arithmetic expression is a %s instead of an integer",
                    types.tostring(exp.lhs._type))
            end
            if exp.rhs._type._tag ~= types.T.Integer then
                type_error(exp.loc,
                    "right hand side of arithmetic expression is a %s instead of an integer",
                    types.tostring(exp.rhs._type))
            end
            exp._type = types.T.Integer()
        else
            error("impossible")
        end

    elseif tag == ast.Exp.CallFunc then
        local fexp = exp.exp
        local args = exp.args

        check_exp(fexp, false)
        local ftype = fexp._type

        if ftype._tag == types.T.Function then
            if #ftype.params ~= #args then
                type_error(exp.loc,
                    "function expects %d argument(s) but received %d",
                    #ftype.params, #args)
            end
            for i = 1, math.min(#ftype.params, #args) do
                local ptype = ftype.params[i]
                local arg = args[i]
                check_exp(arg, ptype)
                checkmatch(fexp.loc,
                    ptype, arg._type,
                    "argument %d of call to function", i)
            end
            assert(#ftype.rettypes <= 1)
            if #ftype.rettypes >= 1 then
                exp._type = ftype.rettypes[1]
            else
                exp._type = types.T.Void()
            end
        elseif ftype._tag == types.T.Builtin then
            check_exp_callfunc_builtin(exp, false)
        else
            type_error(exp.loc,
                "attempting to call a %s value",
                types.tostring(exp.exp._type))
        end

    elseif tag == ast.Exp.CallMethod then
        error("not implemented")

    elseif tag == ast.Exp.Cast then
        local target = check_type(exp.target)
        check_exp(exp.exp, target)
        if not types.coerceable(exp.exp._type, target) then
            type_error(exp.loc,
                "cannot cast '%s' to '%s'",
                types.tostring(exp.exp._type), types.tostring(target))
        end
        exp._type = target

    else
        error("impossible")
    end
end

return checker
