local checker = {}

local location = require "titan-compiler.location"
local symtab = require "titan-compiler.symtab"
local types = require "titan-compiler.types"
local ast = require "titan-compiler.ast"
local util = require "titan-compiler.util"

local check_type
local check_toplevel
local check_decl
local check_stat
local check_then
local check_var
local check_exp
local check_args
local check_field

-- XXX those will vanish when we remove global letrec
local checktoplevel
local checkbodies

-- Type-check a Titan module
--
-- Sets a _type field on some nodes. TODO: what nodes?
--
-- @ param prog AST for the whole module
-- @ return true, or false followed by as list of compilation errors
function checker.check(prog)
    local errors = {}
    checktoplevel(prog, errors)
    checkbodies(prog, errors)
    return (#errors == 0), errors
end

--
-- local functions
--

function type_error(errors, loc, fmt, ...)
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
    if types.coerceable(found, expected) or not types.equals(expected, found) then
        local msg = "types in %s do not match, expected %s but found %s"
        msg = string.format(msg, term, types.tostring(expected), types.tostring(found))
        type_error(errors, loc, msg)
    end
end

local function trycoerce(node, target, errors)
    if types.coerceable(node._type, target) then
        local n = ast.Exp.Cast(node.loc, node, nil)
        n._type = target
        return n
    else
        return node
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
        local name = node.name
        if node._decl._tag == ast.Toplevel.Record then
            -- TODO: fix record types
            return node._decl._type.type
        else
            type_error(errors, node.loc, "%s isn't a type", name)
            return types.T.Invalid()
        end

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

-- TODO check_toplevel here
-- check_toplevel = function...

check_decl = function(node, errors)
    node._type = node._type or check_type(node.type, errors)
end

check_stat = function(node, errors)
    local tag = node._tag
    if     tag == ast.Stat.Decl then
        if node.decl.type then
          check_decl(node.decl, errors)
          check_exp(node.exp, errors, node.decl._type)
        else
          check_exp(node.exp, errors)
          node.decl._type = node.exp._type
          check_decl(node.decl, errors)
        end
        checkmatch("declaration of local variable " .. node.decl.name,
            node.decl._type, node.exp._type, errors, node.decl.loc)
        return false

    elseif tag == ast.Stat.Block then
        local ret = false
        for _, stat in ipairs(node.stats) do
            ret = ret or check_stat(stat, errors)
        end
        return ret

    elseif tag == ast.Stat.While then
        check_exp(node.condition, errors, types.T.Boolean())
        check_stat(node.block, errors)
        return false

    elseif tag == ast.Stat.Repeat then
        for _, stat in ipairs(node.block.stats) do
            check_stat(stat, errors)
        end
        check_exp(node.condition, errors, types.T.Boolean())
        return false

    elseif tag == ast.Stat.For then
        check_exp(node.start, errors)
        check_exp(node.finish, errors)
        if node.inc then
            check_exp(node.inc, errors)
        end
        -- Add loop variable to symbol table only after checking expressions
        if not node.decl.type then
            node.decl._type = node.start._type
        end
        check_decl(node.decl, errors)

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

        check_stat(node.block, errors)
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
            -- mark this declared variable as assigned to
            if node.var._tag == ast.Var.Name and node.var._decl then
                node.var._decl._assigned = true
            end
            if node.var._tag ~= ast.Var.Bracket or node.exp._type._tag ~= types.T.Nil then
                checkmatch("assignment", node.var._type, node.exp._type, errors, node.var.loc)
            end
        end
        return false

    elseif tag == ast.Stat.Call then
        check_exp(node.callexp, errors)
        return false

    elseif tag == ast.Stat.Return then
        --local ftype = st:find_symbol("$function")._type
        --assert(#ftype.rettypes == 1)
        --local tret = ftype.rettypes[1]
        --check_exp(node.exp, st, errors, tret)
        --checkmatch("return", tret, node.exp._type, errors, node.exp.loc)
        check_exp(node.exp, errors)
        return true

    elseif tag == ast.Stat.If then
        local ret = true
        for _, thn in ipairs(node.thens) do
            check_exp(thn.condition, errors, types.T.Boolean())
            ret = check_stat(thn.block, errors) and ret
        end
        if node.elsestat then
            ret = check_stat(node.elsestat, errors) and ret
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
        node._decl._used = true
        node._type = node._decl._type

    elseif tag == ast.Var.Dot then
        local var = assert(node.exp.var, "left side of dot is not var")
        check_var(var, errors)
        node.exp._type = var._type
        local vartype = var._type
        if vartype._tag == types.T.Module then
            local mod = vartype
            if not mod.members[node.name] then
                type_error(errors, node.loc,
                    "variable '%s' not found inside module '%s'",
                    node.name, mod.name)
            else
                local decl = mod.members[node.name]
                node._decl = decl
                node._type = decl
            end
        elseif vartype._tag == types.T.Type then
            local typ = vartype.type
            if typ._tag == types.T.Record then
                if node.name == "new" then
                    local params = {}
                    for _, field in ipairs(typ.fields) do
                        table.insert(params, field.type)
                    end
                    node._decl = typ
                    node._type = types.T.Function(params, {typ})
                else
                    type_error(errors, node.loc,
                        "trying to access invalid record member '%s'", node.name)
                end
            else
                type_error(errors, node.loc,
                    "invalid access to type '%s'", types.tostring(type))
            end
        elseif vartype._tag == types.T.Record then
            for _, field in ipairs(vartype.fields) do
                if field.name == node.name then
                    node._type = field.type
                    break
                end
            end
            if not node._type then
                type_error(errors, node.loc,
                    "field '%s' not found in record '%s'",
                    node.name, vartype.name)
            end
        else
            type_error(errors, node.loc,
                "trying to access a member of value of type '%s'",
                types.tostring(vartype))
        end
        node._type = node._type or types.T.Invalid()

    elseif tag == ast.Var.Bracket then
        check_exp(node.exp1, errors, context and types.T.Array(context))
        if node.exp1._type._tag ~= types.T.Array then
            type_error(errors, node.exp1.loc,
                "array expression in indexing is not an array but %s",
                types.tostring(node.exp1._type))
            node._type = types.T.Invalid()
        else
            node._type = node.exp1._type.elem
        end
        check_exp(node.exp2, errors, types.T.Integer())
        checkmatch("array indexing", types.T.Integer(), node.exp2._type, errors, node.exp2.loc)

    else
        error("impossible")
    end
end

check_exp = function(node, errors)
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
        local econtext = context and context.elem
        local etypes = {}
        local isarray = true
        for _, field in ipairs(node.fields) do
            local exp = field.exp
            check_exp(exp, errors, econtext)
            table.insert(etypes, exp._type)
            isarray = isarray and not field.name
        end
        if isarray then
            local etype = econtext or etypes[1] or types.T.Integer()
            node._type = types.T.Array(etype)
            for i, field in ipairs(node.fields) do
                local exp = field.exp
                checkmatch("array initializer at position " .. i, etype,
                           exp._type, errors, exp.loc)
            end
        else
            node._type = types.T.Initlist(etypes)
        end

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
        local op = node.op
        check_exp(node.exp, errors)
        local texp = node.exp._type
        local loc = node.loc
        if op == "#" then
            if texp._tag ~= types.T.Array and texp._tag ~= types.T.String then
                type_error(errors, loc,
                    "trying to take the length of a %s instead of an array or string",
                    types.tostring(texp))
            end
            node._type = types.T.Integer()
        elseif op == "-" then
            if texp._tag ~= types.T.Integer and texp._tag ~= types.T.Float then
                type_error(errors, loc,
                    "trying to negate a %s instead of a number",
                    types.tostring(texp))
            end
            node._type = texp
        elseif op == "~" then
            if texp._tag ~= types.T.Integer then
                type_error(errors, loc,
                    "trying to bitwise negate a %s instead of an integer",
                    types.tostring(texp))
            end
            node._type = types.T.Integer()
        elseif op == "not" then
            if texp._tag ~= types.T.Boolean then
                -- Titan is being intentionaly restrictive here
                type_error(errors, loc,
                    "trying to boolean negate a %s instead of a boolean",
                    types.tostring(texp))
            end
            node._type = types.T.Boolean()
        else
            error("impossible")
        end

    elseif tag == ast.Exp.Concat then
        for i, exp in ipairs(node.exps) do
            check_exp(exp, errors, types.T.String())
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
        local op = node.op
        check_exp(node.lhs, errors)
        local tlhs = node.lhs._type
        check_exp(node.rhs, errors)
        local trhs = node.rhs._type
        local loc = node.loc
        if op == "==" or op == "~=" then
            if (tlhs._tag == types.T.Integer and trhs._tag == types.T.Float) or
               (tlhs._tag == types.T.Float   and trhs._tag == types.T.Integer) then
                type_error(errors, loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
            elseif not types.equals(tlhs, trhs) then
                type_error(errors, loc,
                    "cannot compare %s and %s with %s",
                    types.tostring(tlhs), types.tostring(trhs), op)
            end
            node._type = types.T.Boolean()
        elseif op == "<" or op == ">" or op == "<=" or op == ">=" then
            if (tlhs._tag == types.T.Integer and trhs._tag == types.T.Integer) or
               (tlhs._tag == types.T.Float   and trhs._tag == types.T.Float) or
               (tlhs._tag == types.T.String  and trhs._tag == types.T.String) then
               -- OK
            elseif (tlhs._tag == types.T.Integer and trhs._tag == types.T.Float) or
                   (tlhs._tag == types.T.Float   and trhs._tag == types.T.Integer) then
                type_error(errors, loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
            else
                type_error(errors, loc,
                    "cannot compare %s and %s with %s",
                    types.tostring(tlhs), types.tostring(trhs), op)
            end
            node._type = types.T.Boolean()
        elseif op == "+" or op == "-" or op == "*" or op == "%" or op == "//" then
            if not (tlhs._tag == types.T.Integer or tlhs._tag == types.T.Float) then
                type_error(errors, loc,
                    "left hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(tlhs))
            end
            if not (trhs._tag == types.T.Integer or trhs._tag == types.T.Float) then
                type_error(errors, loc,
                    "right hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(trhs))
            end
            -- tries to coerce to float if either side is float
            if tlhs._tag == types.T.Float or trhs._tag == types.T.Float then
                node.lhs = trycoerce(node.lhs, types.T.Float(), errors)
                tlhs = node.lhs._type
                node.rhs = trycoerce(node.rhs, types.T.Float(), errors)
                trhs = node.rhs._type
            end
            if tlhs._tag == types.T.Float and trhs._tag == types.T.Float then
                node._type = types.T.Float()
            elseif tlhs._tag == types.T.Integer and trhs._tag == types.T.Integer then
                node._type = types.T.Integer()
            else
                -- error
                node._type = types.T.Invalid()
            end
        elseif op == "/" or op == "^" then
            if tlhs._tag == types.T.Integer then
                -- always tries to coerce to float
                node.lhs = trycoerce(node.lhs, types.T.Float(), errors)
                tlhs = node.lhs._type
            end
            if trhs._tag == types.T.Integer then
                -- always tries to coerce to float
                node.rhs = trycoerce(node.rhs, types.T.Float(), errors)
                trhs = node.rhs._type
            end
            if tlhs._tag ~= types.T.Float then
                type_error(errors, loc,
                    "left hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(tlhs))
            end
            if trhs._tag ~= types.T.Float then
                type_error(errors, loc,
                    "right hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(trhs))
            end
            node._type = types.T.Float()
        elseif op == "and" or op == "or" then
            if tlhs._tag ~= types.T.Boolean then
                type_error(errors, loc,
                    "left hand side of logical expression is a %s instead of a boolean",
                    types.tostring(tlhs))
            end
            if trhs._tag ~= types.T.Boolean then
                type_error(errors, loc,
                    "right hand side of logical expression is a %s instead of a boolean",
                    types.tostring(trhs))
            end
            node._type = types.T.Boolean()
        elseif op == "|" or op == "&" or op == "<<" or op == ">>" then
            if tlhs._tag ~= types.T.Integer then
                type_error(errors, loc,
                    "left hand side of arithmetic expression is a %s instead of an integer",
                    types.tostring(tlhs))
            end
            if trhs._tag ~= types.T.Integer then
                type_error(errors, loc,
                    "right hand side of arithmetic expression is a %s instead of an integer",
                    types.tostring(trhs))
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
            for _, arg in ipairs(node.args.args) do
                check_exp(arg, errors)
            end
            node._type = types.T.Invalid()
        end

    elseif tag == ast.Exp.Cast then
        local target = check_type(node.target, errors)
        check_exp(node.exp, errors, target)
        if not types.coerceable(node.exp._type, target) and
          not types.equals(node.exp._type, target) then
            type_error(errors, node.loc,
                "cannot cast '%s' to '%s'",
                types.tostring(node.exp._type), types.tostring(target))
        end
        node._type = target

    else
        error("impossible")
    end
end

--
-- TODO The code below should be removed (letrec refac)
--

-- Typechecks a function body
--   node: TopLevelFunc AST node
--   errors: list of compile-time errors
local function checkfunc(node, errors)
    local ptypes = node._type.params
    local pnames = {}
    for i, param in ipairs(node.params) do
        param._type = ptypes[i]
        if pnames[param.name] then
            type_error(errors, node.loc,
                "duplicate parameter '%s' in declaration of function '%s'",
                param.name, node.name)
        else
            pnames[param.name] = true
        end
    end
    assert(#node._type.rettypes == 1)
    local ret = check_stat(node.block, errors)
    if not ret and node._type.rettypes[1]._tag ~= types.T.Nil then
        type_error(errors, node.loc,
            "function can return nil but return type is not nil")
    end
end

-- Checks function bodies
--   prog: AST for the whole module
--   errors: list of compile-time errors
checkbodies = function(prog, errors)
    for _, node in ipairs(prog) do
        if not node._ignore and
           node._tag == ast.Toplevel.Func then
            checkfunc(node, errors)
        end
    end
end

local function isconstructor(node)
    return node.var and node.var._decl and node.var._decl._tag == types.T.Record
end

-- Verify if an expression is constant
local function isconst(node)
    local tag = node._tag
    if tag == ast.Exp.Nil or
       tag == ast.Exp.Bool or
       tag == ast.Exp.Integer or
       tag == ast.Exp.Float or
       tag == ast.Exp.String then
        return true

    elseif tag == ast.Exp.Initlist then
        local const = true
        for _, field in ipairs(node.fields) do
            const = const and isconst(field.exp)
        end
        return const

    elseif tag == ast.Exp.Call then
        if isconstructor(node.exp) then
            local const = true
            for _, arg in ipairs(node.args) do
                const = const and isconst(arg)
            end
            return const
        else
            return false
        end

    elseif tag == ast.Exp.Var then
        return false

    elseif tag == ast.Exp.Concat then
        local const = true
        for _, exp in ipairs(node.exps) do
            const = const and isconst(exp)
        end
        return const

    elseif tag == ast.Exp.Unop then
        return isconst(node.exp)

    elseif tag == ast.Exp.Binop then
        return isconst(node.lhs) and isconst(node.rhs)

    elseif tag == ast.Exp.Cast then
        return isconst(node.exp)

    else
        error("impossible")
    end
end

-- Return the name given the toplevel node
local function toplevel_name(node)
    local tag = node._tag
    if tag == ast.Toplevel.Import then
        return node.localname
    elseif tag == ast.Toplevel.Var then
        return node.decl.name
    elseif tag == ast.Toplevel.Func or
           tag == ast.Toplevel.Record then
        return node.name
    else
        error("impossible")
    end
end

-- Typecheck the toplevel node
toplevel_visitor = function(node, errors, loader)
    local tag = node._tag
    if     tag == ast.Toplevel.Import then
        local modtype, errs = checker.checkimport(node.modname, loader)
        if modtype then
            node._type = modtype
            for _, err in ipairs(errs) do
                table.insert(errors, err)
            end
        else
            node._type = types.T.Nil()
            type_error(errors, node.loc,
                "problem loading module '%s': %s",
                node.modname, errs)
        end

    elseif tag == ast.Toplevel.Var then
        if node.decl.type then
            node._type = check_type(node.decl.type, errors)
            check_exp(node.value, errors, node._type)
            checkmatch("declaration of module variable " .. node.decl.name,
                       node._type, node.value._type, errors, node.loc)
        else
            check_exp(node.value, errors)
            node._type = node.value._type
        end
        if not isconst(node.value) then
            type_error(errors, node.value.loc,
                "top level variable initialization must be constant")
        end

    elseif tag == ast.Toplevel.Func then
        if #node.rettypes ~= 1 then
            error("functions with 0 or 2+ return values are not yet implemented")
        end
        local ptypes = {}
        for _, pdecl in ipairs(node.params) do
            table.insert(ptypes, check_type(pdecl.type, errors))
        end
        local rettypes = {}
        for _, rt in ipairs(node.rettypes) do
            table.insert(rettypes, check_type(rt, errors))
        end
        node._type = types.T.Function(ptypes, rettypes)

    elseif tag == ast.Toplevel.Record then
        local field_decls = {}
        for _, field_decl in ipairs(node.field_decls) do
            local typ = check_type(field_decl.type, errors)
            table.insert(field_decls, {type = typ, name = field_decl.name})
        end
        node._type = types.T.Type(types.T.Record(node.name, field_decls))

    else
        error("impossible")
    end
end

-- Colect type information of toplevel nodes
--   prog: AST for the whole module
--   errors: list of compile-time errors
--   annotates the top-level nodes with their types in a "_type" field
--   annotates whether a top-level declaration is duplicated with a "_ignore"
--   field
checktoplevel = function(prog, errors, loader)
    for _, node in ipairs(prog) do
        local name = toplevel_name(node)
        toplevel_visitor(node, errors, loader)
    end
end

return checker
