local checker = {}

local location = require "titan-compiler.location"
local types = require "titan-compiler.types"
local ast = require "titan-compiler.ast"

local check_program
local check_type
local check_toplevel
local check_decl
local check_stat
local check_then
local check_var
local check_exp
local check_args
local check_field

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
    local errors = {}
    check_program(prog, errors)
    return (#errors == 0), errors
end

--
-- local functions
--

local function type_error(errors, loc, fmt, ...)
    local errmsg = location.format_error(loc, "type error: "..fmt, ...)
    table.insert(errors, errmsg)
end

-- Checks if two types are the same, and logs an error message otherwise
--   term: string describing what is being compared
--   expected: type that is expected
--   found: type that was actually present
--   errors: list of compile-time errors
--   loc: location of the term that is being compared
local function checkmatch(term, expected, found, errors, loc)
    if not types.equals(expected, found) then
        local msg = "types in %s do not match, expected %s but found %s"
        msg = string.format(msg, term, types.tostring(expected), types.tostring(found))
        type_error(errors, loc, msg)
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

local function trytostr(node)
    local source = node._type
    if source._tag == types.T.Integer or
       source._tag == types.T.Float then
        local n = ast.Exp.Cast(node.loc, node, types.T.String())
        n._type = types.T.String()
        return n
    else
        return node
    end
end

--
-- check
--

check_program = function(prog, errors)
    for _, tlnode in ipairs(prog) do
        check_toplevel(tlnode, errors)
    end
end

check_type = function(node, errors)
    local tag = node._tag
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
        return node._decl._type

    elseif tag == ast.Type.Array then
        return types.T.Array(check_type(node.subtype, errors))

    elseif tag == ast.Type.Function then
        if #node.argtypes ~= 1 then
            error("functions with 0 or 2+ return values are not yet implemented")
        end
        local ptypes = {}
        for _, ptype in ipairs(node.argtypes) do
            table.insert(ptypes, check_type(ptype, errors))
        end
        local rettypes = {}
        for _, rettype in ipairs(node.rettypes) do
            table.insert(rettypes, check_type(rettype, errors))
        end
        return types.T.Function(ptypes, rettypes)

    else
        error("impossible")
    end
end

check_toplevel = function(node, errors, loader)
    local tag = node._tag
    if     tag == ast.Toplevel.Import then
        type_error(errors, node.loc, "modules are not implemented yet")

    elseif tag == ast.Toplevel.Var then
        if node.decl.type then
            node._type = check_type(node.decl.type, errors)
            check_exp(node.value, errors, node._type)
            checkmatch("declaration of module variable " .. node.decl.name,
                       node._type, node.value._type, errors, node.loc)
        else
            check_exp(node.value, errors, nil)
            node._type = node.value._type
        end

    elseif tag == ast.Toplevel.Func then
        if #node.rettypes ~= 1 then
            error("functions with 0 or 2+ return values are not yet implemented")
        end

        local ptypes = {}
        for _, param in ipairs(node.params) do
            param._type = check_type(param.type, errors)
            table.insert(ptypes, param._type)
        end

        local rettypes = {}
        for _, rt in ipairs(node.rettypes) do
            table.insert(rettypes, check_type(rt, errors))
        end
        node._type = types.T.Function(ptypes, rettypes)

        local ret = check_stat(node.block, errors, rettypes)
        if not ret and node._type.rettypes[1]._tag ~= types.T.Nil then
            type_error(errors, node.loc,
                "control reaches end of function with non-nil return type")
        end

    elseif tag == ast.Toplevel.Record then
        node._field_types = {}
        for _, field_decl in ipairs(node.field_decls) do
            local typ = check_type(field_decl.type, errors)
            node._field_types[field_decl.name] = typ
        end

        node._type = types.T.Record(node)

    else
        error("impossible")
    end
end

check_decl = function(node, errors)
    node._type = node._type or check_type(node.type, errors)
end

-- @param rettypes Declared function return types (for return statements)
check_stat = function(node, errors, rettypes)
    local tag = node._tag
    if     tag == ast.Stat.Decl then
        if node.decl.type then
          check_decl(node.decl, errors)
          check_exp(node.exp, errors, node.decl._type)
        else
          check_exp(node.exp, errors, nil)
          node.decl._type = node.exp._type
          check_decl(node.decl, errors)
        end
        checkmatch("declaration of local variable " .. node.decl.name,
            node.decl._type, node.exp._type, errors, node.decl.loc)
        return false

    elseif tag == ast.Stat.Block then
        local ret = false
        for _, stat in ipairs(node.stats) do
            ret = ret or check_stat(stat, errors, rettypes)
        end
        return ret

    elseif tag == ast.Stat.While then
        check_exp(node.condition, errors, nil)
        checkmatch("while statement condition",
            types.T.Boolean(), node.condition._type, errors, node.condition.loc)
        check_stat(node.block, errors, rettypes)
        return false

    elseif tag == ast.Stat.Repeat then
        for _, stat in ipairs(node.block.stats) do
            check_stat(stat, errors, rettypes)
        end
        check_exp(node.condition, errors, nil)
        checkmatch("repeat statement condition",
            types.T.Boolean(), node.condition._type, errors, node.condition.loc)
        return false

    elseif tag == ast.Stat.For then
        if node.decl.type then
            check_decl(node.decl, errors)
        end
        check_exp(node.start, errors, node.decl._type)
        check_exp(node.finish, errors, node.decl._type)
        if node.inc then
            check_exp(node.inc, errors, node.decl._type)
        end
        if not node.decl.type then
            node.decl._type = node.start._type
        end

        local loop_type_is_valid
        if     node.decl._type._tag == types.T.Integer then
            loop_type_is_valid = true
            if not node.inc then
                node.inc = ast.Exp.Integer(node.finish.loc, 1)
                node.inc._type = types.T.Integer()
            end
        elseif node.decl._type._tag == types.T.Float then
            loop_type_is_valid = true
            if not node.inc then
                node.inc = ast.Exp.Float(node.finish.loc, 1.0)
                node.inc._type = types.T.Float()
            end
        else
            loop_type_is_valid = false
            type_error(errors, node.decl.loc,
                "type of for control variable %s must be integer or float",
                node.decl.name)
        end

        if loop_type_is_valid then
            checkmatch("'for' start expression",
                node.decl._type, node.start._type, errors, node.start.loc)
            checkmatch("'for' finish expression",
                node.decl._type, node.finish._type, errors, node.finish.loc)
            checkmatch("'for' step expression",
                node.decl._type, node.inc._type, errors, node.inc.loc)
        end

        check_stat(node.block, errors, rettypes)
        return false

    elseif tag == ast.Stat.Assign then
        check_var(node.var, errors)
        check_exp(node.exp, errors, node.var._type)
        local texp = node.var._type
        if texp._tag == types.T.Module then
            type_error(errors, node.loc, "trying to assign to a module")
        elseif texp._tag == types.T.Function then
            type_error(errors, node.loc, "trying to assign to a function")
        else
            if node.var._tag ~= ast.Var.Bracket or node.exp._type._tag ~= types.T.Nil then
                checkmatch("assignment", node.var._type, node.exp._type, errors, node.var.loc)
            end
        end
        return false

    elseif tag == ast.Stat.Call then
        check_exp(node.callexp, errors, nil)
        return false

    elseif tag == ast.Stat.Return then
        assert(#rettypes == 1)
        local rettype = rettypes[1]
        check_exp(node.exp, errors, rettype)
        checkmatch("return statement", rettype, node.exp._type, errors, node.exp.loc)
        return true

    elseif tag == ast.Stat.If then
        local ret = true
        for _, thn in ipairs(node.thens) do
            check_exp(thn.condition, errors, nil)
            checkmatch("if statement condition",
                types.T.Boolean(), thn.condition._type, errors, thn.loc)
            ret = check_stat(thn.block, errors, rettypes) and ret
        end
        if node.elsestat then
            ret = check_stat(node.elsestat, errors, rettypes) and ret
        else
            ret = false
        end
        return ret

    else
        error("impossible")
    end
end

check_var = function(node, errors)
    local tag = node._tag
    if     tag == ast.Var.Name then
        node._type = node._decl._type

    elseif tag == ast.Var.Dot then
        check_exp(node.exp, errors, nil)
        local exptype = node.exp._type
        if exptype._tag == types.T.Record then
            local field_type = exptype.type_decl._field_types[node.name]
            if field_type then
                node._type = field_type
            else
                type_error(errors, node.loc,
                    "field '%s' not found in record '%s'",
                    node.name, exptype.type_decl.name)
                node._type = types.T.Invalid()
            end
        else
            type_error(errors, node.loc,
                "trying to access a member of value of type '%s'",
                types.tostring(exptype))
            node._type = types.T.Invalid()
        end

    elseif tag == ast.Var.Bracket then
        check_exp(node.exp1, errors, nil)
        if node.exp1._type._tag ~= types.T.Array then
            type_error(errors, node.exp1.loc,
                "array expression in indexing is not an array but %s",
                types.tostring(node.exp1._type))
            node._type = types.T.Invalid()
        else
            node._type = node.exp1._type.elem
        end
        check_exp(node.exp2, errors, nil)
        checkmatch("array indexing", types.T.Integer(), node.exp2._type, errors, node.exp2.loc)

    else
        error("impossible")
    end
end

-- @param typehint Expected type; Used to infer polymorphic/record constructors.
check_exp = function(node, errors, typehint)
    local tag = node._tag
    if     tag == ast.Exp.Nil then
        node._type = types.T.Nil()

    elseif tag == ast.Exp.Bool then
        node._type = types.T.Boolean()

    elseif tag == ast.Exp.Integer then
        node._type = types.T.Integer()

    elseif tag == ast.Exp.Float then
        node._type = types.T.Float()

    elseif tag == ast.Exp.String then
        node._type = types.T.String()

    elseif tag == ast.Exp.Initlist then
        -- Determining the type for a table initializer *requires* a type hint.
        -- In theory, we could try to infer the type without a type hint for
        -- non-empty arrays whose contents are inferrable, but I am not sure
        -- we should treat that case differently from the others...
        if typehint then
            if typehint._tag == types.T.Array then
                for _, field in ipairs(node.fields) do
                    if field.name then
                        type_error(errors, field.loc,
                            "named field %s in array initializer",
                            field.name)
                    else
                        local field_type = typehint.elem
                        check_exp(field.exp, errors, field_type)
                        checkmatch("array initializer",
                            field_type, field.exp._type, errors, field.loc)
                    end
                end

            elseif typehint._tag == types.T.Record then
                local initialized_fields = {}
                for _, field in ipairs(node.fields) do
                    if field.name then
                        local field_type = typehint.type_decl._field_types[field.name]
                        if field_type then
                            initialized_fields[field.name] = true
                            check_exp(field.exp, errors, field_type)
                            checkmatch("record initializer",
                                field_type, field.exp._type, errors, field.loc)
                        else
                            type_error(errors, field.loc,
                                "invalid field %s in record initializer for %s",
                                field.name, typehint.type_decl.name)
                        end
                    else
                        type_error(errors, field.loc,
                            "record initializer has array part")
                    end
                end

                for field_name, _ in pairs(typehint.type_decl._field_types) do
                    if not initialized_fields[field_name] then
                        type_error(errors, node.loc,
                            "required field %s is missing from initializer",
                            field_name)
                    end
                end
            else
                type_error(errors, node.loc,
                    "type hint for array or record initializer is not an array or record type")
            end
        else
            type_error(errors, node.loc,
                "missing type hint for array or record initializer")
        end

        node._type = typehint or types.T.Invalid()

    elseif tag == ast.Exp.Var then
        check_var(node.var, errors, context)
        local texp = node.var._type
        if texp._tag == types.T.Module then
            type_error(errors, node.loc,
                "trying to access module '%s' as a first-class value",
                node.var.name)
            node._type = types.T.Invalid()
        elseif texp._tag == types.T.Function then
            type_error(errors, node.loc,
                "trying to access a function as a first-class value")
            node._type = types.T.Invalid()
        else
            node._type = texp
        end

    elseif tag == ast.Exp.Unop then
        check_exp(node.exp, errors, nil)
        local op = node.op
        if op == "#" then
            if node.exp._type._tag ~= types.T.Array and node.exp._type._tag ~= types.T.String then
                type_error(errors, node.loc,
                    "trying to take the length of a %s instead of an array or string",
                    types.tostring(node.exp._type))
            end
            node._type = types.T.Integer()
        elseif op == "-" then
            if node.exp._type._tag ~= types.T.Integer and node.exp._type._tag ~= types.T.Float then
                type_error(errors, node.loc,
                    "trying to negate a %s instead of a number",
                    types.tostring(node.exp._type))
            end
            node._type = node.exp._type
        elseif op == "~" then
            if node.exp._type._tag ~= types.T.Integer then
                type_error(errors, node.loc,
                    "trying to bitwise negate a %s instead of an integer",
                    types.tostring(node.exp._type))
            end
            node._type = types.T.Integer()
        elseif op == "not" then
            if node.exp._type._tag ~= types.T.Boolean then
                -- Titan is being intentionaly restrictive here
                type_error(errors, node.loc,
                    "trying to boolean negate a %s instead of a boolean",
                    types.tostring(node.exp._type))
            end
            node._type = types.T.Boolean()
        else
            error("impossible")
        end

    elseif tag == ast.Exp.Concat then
        for i, exp in ipairs(node.exps) do
            check_exp(exp, errors, nil)
            -- always tries to coerce numbers to string
            exp = trytostr(exp)
            node.exps[i] = exp
            local texp = exp._type
            if texp._tag ~= types.T.String then
                type_error(errors, exp.loc,
                    "cannot concatenate with %s value", types.tostring(texp))
            end
        end
        node._type = types.T.String()

    elseif tag == ast.Exp.Binop then
        check_exp(node.lhs, errors, nil)
        check_exp(node.rhs, errors, nil)
        local op = node.op
        if op == "==" or op == "~=" then
            if (node.lhs._type._tag == types.T.Integer and node.rhs._type._tag == types.T.Float) or
               (node.lhs._type._tag == types.T.Float   and node.rhs._type._tag == types.T.Integer) then
                type_error(errors, node.loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
            elseif not types.equals(node.lhs._type, node.rhs._type) then
                type_error(errors, node.loc,
                    "cannot compare %s and %s with %s",
                    types.tostring(node.lhs._type), types.tostring(node.rhs._type), op)
            end
            node._type = types.T.Boolean()
        elseif op == "<" or op == ">" or op == "<=" or op == ">=" then
            if (node.lhs._type._tag == types.T.Integer and node.rhs._type._tag == types.T.Integer) or
               (node.lhs._type._tag == types.T.Float   and node.rhs._type._tag == types.T.Float) or
               (node.lhs._type._tag == types.T.String  and node.rhs._type._tag == types.T.String) then
               -- OK
            elseif (node.lhs._type._tag == types.T.Integer and node.rhs._type._tag == types.T.Float) or
                   (node.lhs._type._tag == types.T.Float   and node.rhs._type._tag == types.T.Integer) then
                type_error(errors, node.loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
            else
                type_error(errors, node.loc,
                    "cannot compare %s and %s with %s",
                    types.tostring(node.lhs._type), types.tostring(node.rhs._type), op)
            end
            node._type = types.T.Boolean()

        elseif op == "+" or op == "-" or op == "*" or op == "%" or op == "//" then
            if is_numeric_type(node.lhs._type) and is_numeric_type(node.rhs._type) then
                if node.lhs._type._tag == types.T.Integer and
                   node.rhs._type._tag == types.T.Integer then
                    node._type = types.T.Integer()
                else
                    node.lhs = coerce_numeric_exp_to_float(node.lhs)
                    node.rhs = coerce_numeric_exp_to_float(node.rhs)
                    node._type = types.T.Float()
                end
            else
                if not is_numeric_type(node.lhs._type) then
                    type_error(errors, node.loc,
                        "left hand side of arithmetic expression is a %s instead of a number",
                        types.tostring(node.lhs._type))
                end
                if not is_numeric_type(node.lhs._type) then
                    type_error(errors, node.loc,
                        "right hand side of arithmetic expression is a %s instead of a number",
                        types.tostring(node.rhs._type))
                end
                node._type = types.T.Invalid()
            end

        elseif op == "/" or op == "^" then
            if is_numeric_type(node.lhs._type) and is_numeric_type(node.rhs._type) then
                node.lhs = coerce_numeric_exp_to_float(node.lhs)
                node.rhs = coerce_numeric_exp_to_float(node.rhs)
                node._type = types.T.Float()
            else
                if not is_numeric_type(node.lhs._type._tag) then
                    type_error(errors, node.loc,
                        "left hand side of arithmetic expression is a %s instead of a number",
                        types.tostring(node.lhs._type))
                end
                if not is_numeric_type(node.rhs._type._tag) then
                    type_error(errors, node.loc,
                        "right hand side of arithmetic expression is a %s instead of a number",
                        types.tostring(node.rhs._type))
                end
                node._type = types.T.Float()
            end

        elseif op == "and" or op == "or" then
            if node.lhs._type._tag ~= types.T.Boolean then
                type_error(errors, node.loc,
                    "left hand side of logical expression is a %s instead of a boolean",
                    types.tostring(node.lhs._type))
            end
            if node.rhs._type._tag ~= types.T.Boolean then
                type_error(errors, node.loc,
                    "right hand side of logical expression is a %s instead of a boolean",
                    types.tostring(node.rhs._type))
            end
            node._type = types.T.Boolean()
        elseif op == "|" or op == "&" or op == "<<" or op == ">>" then
            if node.lhs._type._tag ~= types.T.Integer then
                type_error(errors, node.loc,
                    "left hand side of arithmetic expression is a %s instead of an integer",
                    types.tostring(node.lhs._type))
            end
            if node.rhs._type._tag ~= types.T.Integer then
                type_error(errors, node.loc,
                    "right hand side of arithmetic expression is a %s instead of an integer",
                    types.tostring(node.rhs._type))
            end
            node._type = types.T.Integer()
        else
            error("impossible")
        end

    elseif tag == ast.Exp.Call then
        assert(node.exp._tag == ast.Exp.Var, "function calls are first-order only!")
        local var = node.exp.var
        check_var(var, errors)
        node.exp._type = var._type
        local fname = var._tag == ast.Var.Name and var.name or (var.exp.var.name .. "." .. var.name)
        if var._type._tag == types.T.Function then
            local ftype = var._type
            local nparams = #ftype.params
            local args = node.args.args
            local nargs = #args
            local arity = math.max(nparams, nargs)
            for i = 1, arity do
                local arg = args[i]
                local ptype = ftype.params[i]
                local atype
                if not arg then
                    atype = ptype
                else
                    check_exp(arg, errors, ptype)
                    ptype = ptype or arg._type
                    atype = args[i]._type
                end
                if not ptype then
                    ptype = atype
                end
                checkmatch("argument " .. i .. " of call to function '" .. fname .. "'", ptype, atype, errors, node.exp.loc)
            end
            if nargs ~= nparams then
                type_error(errors, node.loc,
                    "function %s called with %d arguments but expects %d",
                    fname, nargs, nparams)
            end
            assert(#ftype.rettypes == 1)
            node._type = ftype.rettypes[1]
        else
            type_error(errors, node.loc,
                "'%s' is not a function but %s",
                fname, types.tostring(var._type))
            node._type = types.T.Invalid()
        end

    elseif tag == ast.Exp.Cast then
        local target = check_type(node.target, errors)
        check_exp(node.exp, errors, target)
        if not types.coerceable(node.exp._type, target) then
            type_error(errors, node.loc,
                "cannot cast '%s' to '%s'",
                types.tostring(node.exp._type), types.tostring(target))
        end
        node._type = target

    else
        error("impossible")
    end
end

return checker
