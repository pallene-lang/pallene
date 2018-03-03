local checker = {}

local location = require "titan-compiler.location"
local symtab = require "titan-compiler.symtab"
local types = require "titan-compiler.types"
local ast = require "titan-compiler.ast"
local util = require "titan-compiler.util"


-- The typechecker works in two passes, the first one just
-- collects type information for top-level functions and variables
-- (and detects duplicate definitions in the top level), while the
-- second pass does the actual typechecking. All typechecked nodes
-- that have a type get a "_type" field with the type. The types
-- themselves are in "types.lua".
local typefromnode

local checkdecl
local checkstat
local checkexp
local checkvar

function checker.typeerror(errors, loc, fmt, ...)
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
        checker.typeerror(errors, loc, msg)
    end
end

-- Converts an AST type declaration into a typechecker type
--   node: AST node
--   errors: list of compile-time errors
--   returns a type (from types.lua)
typefromnode = util.make_visitor({
    [ast.TypeNil] = function(node, st, errors)
        return types.Nil()
    end,

    [ast.TypeBoolean] = function(node, st, errors)
        return types.Boolean()
    end,

    [ast.TypeInteger] = function(node, st, errors)
        return types.Integer()
    end,

    [ast.TypeFloat] = function(node, st, errors)
        return types.Float()
    end,

    [ast.TypeString] = function(node, st, errors)
        return types.String()
    end,

    [ast.TypeName] = function(node, st, errors)
        local name = node.name
        local sym = st:find_symbol(name)
        if sym then
            if sym._type._tag == types.Type then
                return sym._type.type
            else
                checker.typeerror(errors, node.loc, "%s isn't a type", name)
                return types.Invalid()
            end
        else
            checker.typeerror(errors, node.loc, "type '%s' not found", name)
            return types.Invalid()
        end
    end,

    [ast.TypeArray] = function(node, st, errors)
        return types.Array(typefromnode(node.subtype, st, errors))
    end,

    [ast.TypeFunction] = function(node, st, errors)
        if #node.argtypes ~= 1 then
            error("functions with 0 or 2+ return values are not yet implemented")
        end
        local ptypes = {}
        for _, ptype in ipairs(node.argtypes) do
            table.insert(ptypes, typefromnode(ptype, st, errors))
        end
        local rettypes = {}
        for _, rettype in ipairs(node.rettypes) do
            table.insert(rettypes, typefromnode(rettype, st, errors))
        end
        return types.Function(ptypes, rettypes)
    end,
})

-- tries to coerce node to target type
--    node: expression node
--    target: target type
--    returns node wrapped in a coercion, or original node
local function trycoerce(node, target, errors)
    if types.coerceable(node._type, target) then
        local n = ast.ExpCast(node.loc, node, target)
        n._type = target
        return n
    else
        return node
    end
end

local function trytostr(node)
    local source = node._type
    if source._tag == types.Integer or
       source._tag == types.Float then
        local n = ast.ExpCast(node.loc, node, types.String())
        n._type = types.String()
        return n
    else
        return node
    end
end

--
-- Decl
--

checkdecl = function(node, st, errors)
    node._type = node._type or typefromnode(node.type, st, errors)
    st:add_symbol(node.name, node)
end

--
-- Stat
--

-- Typechecks a repeat/until statement
--   node: StatRepeat AST node
--   st: symbol table
--   errors: list of compile-time errors
--   returns whether statement always returns from its function (always false for repeat/until)
local function checkrepeat(node, st, errors)
    for _, stat in ipairs(node.block.stats) do
        checkstat(stat, st, errors)
    end
    checkexp(node.condition, st, errors, types.Boolean())
    return false
end

-- Typechecks a for loop statement
--   node: StatFor AST node
--   st: symbol table
--   errors: list of compile-time errors
--   returns whether statement always returns from its function (always false for 'for' loop)
local function checkfor(node, st, errors)
    checkexp(node.start, st, errors)
    checkexp(node.finish, st, errors)
    if node.inc then
        checkexp(node.inc, st, errors)
    end

    -- Add loop variable to symbol table only after checking expressions
    if not node.decl.type then
        node.decl._type = node.start._type
    end
    checkdecl(node.decl, st, errors)

    local loop_type_is_valid
    if     node.decl._type._tag == types.Integer then
        loop_type_is_valid = true
        if not node.inc then
            node.inc = ast.ExpInteger(node.finish.loc, 1)
            node.inc._type = types.Integer()
        end
    elseif node.decl._type._tag == types.Float then
        loop_type_is_valid = true
        if not node.inc then
            node.inc = ast.ExpFloat(node.finish.loc, 1.0)
            node.inc._type = types.Float()
        end
    else
        loop_type_is_valid = false
        checker.typeerror(errors, node.decl.loc,
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

    checkstat(node.block, st, errors)

    return false
end

-- Typechecks a block statement
--   node: StatBlock AST node
--   st: symbol table
--   errors: list of compile-time errors
--   returns whether the block always returns from the containing function
local function checkblock(node, st, errors)
    local ret = false
    for _, stat in ipairs(node.stats) do
        ret = ret or checkstat(stat, st, errors)
    end
    return ret
end

-- Typechecks a statement or declaration
--   node: A DeclDecl or Stat_* AST node
--   st: symbol table
--   errors: list of compile-time errors
--   returns whether statement always returns from its function (always false for repeat/until)
checkstat = util.make_visitor({
    [ast.StatDecl] = function(node, st, errors)
        if node.decl.type then
          checkdecl(node.decl, st, errors)
          checkexp(node.exp, st, errors, node.decl._type)
        else
          checkexp(node.exp, st, errors)
          node.decl._type = node.exp._type
          checkdecl(node.decl, st, errors)
        end
        checkmatch("declaration of local variable " .. node.decl.name,
            node.decl._type, node.exp._type, errors, node.decl.loc)
    end,

    [ast.StatBlock] = function(node, st, errors)
        return st:with_block(checkblock, node, st, errors)
    end,

    [ast.StatWhile] = function(node, st, errors)
        checkexp(node.condition, st, errors, types.Boolean())
        st:with_block(checkstat, node.block, st, errors)
    end,

    [ast.StatRepeat] = function(node, st, errors)
        st:with_block(checkrepeat, node, st, errors)
    end,

    [ast.StatFor] = function(node, st, errors)
        st:with_block(checkfor, node, st, errors)
    end,

    [ast.StatAssign] = function(node, st, errors)
        checkvar(node.var, st, errors)
        checkexp(node.exp, st, errors, node.var._type)
        local texp = node.var._type
        if texp._tag == types.Module then
            checker.typeerror(errors, node.loc, "trying to assign to a module")
        elseif texp._tag == types.Function then
            checker.typeerror(errors, node.loc, "trying to assign to a function")
        else
            -- mark this declared variable as assigned to
            if node.var._tag == ast.VarName and node.var._decl then
                node.var._decl._assigned = true
            end
            if node.var._tag ~= ast.VarBracket or node.exp._type._tag ~= types.Nil then
                checkmatch("assignment", node.var._type, node.exp._type, errors, node.var.loc)
            end
        end
    end,

    [ast.StatCall] = function(node, st, errors)
        checkexp(node.callexp, st, errors)
    end,

    [ast.StatReturn] = function(node, st, errors)
        local ftype = st:find_symbol("$function")._type
        assert(#ftype.rettypes == 1)
        local tret = ftype.rettypes[1]
        checkexp(node.exp, st, errors, tret)
        checkmatch("return", tret, node.exp._type, errors, node.exp.loc)
        return true
    end,

    [ast.StatIf] = function(node, st, errors)
        local ret = true
        for _, thn in ipairs(node.thens) do
            checkexp(thn.condition, st, errors, types.Boolean())
            ret = checkstat(thn.block, st, errors) and ret
        end
        if node.elsestat then
            ret = checkstat(node.elsestat, st, errors) and ret
        else
            ret = false
        end
        return ret
    end,
})

--
-- Var
--

-- Typechecks an variable node
--   node: Var_* AST node
--   st: symbol table
--   errors: list of compile-time errors
--   context: expected type for this expression, if applicable
--   annotates the node with its type in a "_type" field
checkvar = util.make_visitor({
    [ast.VarName] = function(node, st, errors, context)
        local decl = st:find_symbol(node.name)
        if not decl then
            checker.typeerror(errors, node.loc,
                "variable '%s' not declared", node.name)
            node._type = types.Invalid()
        else
            decl._used = true
            node._decl = decl
            node._type = decl._type
        end
    end,

    [ast.VarDot] = function(node, st, errors)
        local var = assert(node.exp.var, "left side of dot is not var")
        checkvar(var, st, errors)
        node.exp._type = var._type
        local vartype = var._type
        if vartype._tag == types.Module then
            local mod = vartype
            if not mod.members[node.name] then
                checker.typeerror(errors, node.loc,
                    "variable '%s' not found inside module '%s'",
                    node.name, mod.name)
            else
                local decl = mod.members[node.name]
                node._decl = decl
                node._type = decl
            end
        elseif vartype._tag == types.Type then
            local typ = vartype.type
            if typ._tag == types.Record then
                if node.name == "new" then
                    local params = {}
                    for _, field in ipairs(typ.fields) do
                        table.insert(params, field.type)
                    end
                    node._decl = typ
                    node._type = types.Function(params, {typ})
                else
                    checker.typeerror(errors, node.loc,
                        "trying to access invalid record member '%s'", node.name)
                end
            else
                checker.typeerror(errors, node.loc,
                    "invalid access to type '%s'", types.tostring(type))
            end
        elseif vartype._tag == types.Record then
            for _, field in ipairs(vartype.fields) do
                if field.name == node.name then
                    node._type = field.type
                    break
                end
            end
            if not node._type then
                checker.typeerror(errors, node.loc,
                    "field '%s' not found in record '%s'",
                    node.name, vartype.name)
            end
        else
            checker.typeerror(errors, node.loc,
                "trying to access a member of value of type '%s'",
                types.tostring(vartype))
        end
        node._type = node._type or types.Invalid()
    end,

    [ast.VarBracket] = function(node, st, errors, context)
        checkexp(node.exp1, st, errors, context and types.Array(context))
        if node.exp1._type._tag ~= types.Array then
            checker.typeerror(errors, node.exp1.loc,
                "array expression in indexing is not an array but %s",
                types.tostring(node.exp1._type))
            node._type = types.Invalid()
        else
            node._type = node.exp1._type.elem
        end
        checkexp(node.exp2, st, errors, types.Integer())
        checkmatch("array indexing", types.Integer(), node.exp2._type, errors, node.exp2.loc)
    end,
})

--
-- Exp
--

-- Typechecks an expression
--   node: Exp_* AST node
--   st: symbol table
--   errors: list of compile-time errors
--   context: expected type for this expression, if applicable
--   annotates the node with its type in a "_type" field
checkexp = util.make_visitor({
    [ast.ExpNil] = function(node)
        node._type = types.Nil()
    end,

    [ast.ExpBool] = function(node)
        node._type = types.Boolean()
    end,

    [ast.ExpInteger] = function(node)
        node._type = types.Integer()
    end,

    [ast.ExpFloat] = function(node)
        node._type = types.Float()
    end,

    [ast.ExpString] = function(node)
        node._type = types.String()
    end,

    [ast.ExpInitList] = function(node, st, errors, context)
        local econtext = context and context.elem
        local etypes = {}
        local isarray = true
        for _, field in ipairs(node.fields) do
            local exp = field.exp
            checkexp(exp, st, errors, econtext)
            table.insert(etypes, exp._type)
            isarray = isarray and not field.name
        end
        if isarray then
            local etype = econtext or etypes[1] or types.Integer()
            node._type = types.Array(etype)
            for i, field in ipairs(node.fields) do
                local exp = field.exp
                checkmatch("array initializer at position " .. i, etype,
                           exp._type, errors, exp.loc)
            end
        else
            node._type = types.InitList(etypes)
        end
    end,

    [ast.ExpVar] = function(node, st, errors, context)
        checkvar(node.var, st, errors, context)
        local texp = node.var._type
        if texp._tag == types.Module then
            checker.typeerror(errors, node.loc,
                "trying to access module '%s' as a first-class value",
                node.var.name)
            node._type = types.Invalid()
        elseif texp._tag == types.Function then
            checker.typeerror(errors, node.loc,
                "trying to access a function as a first-class value")
            node._type = types.Invalid()
        else
            node._type = texp
        end
    end,

    [ast.ExpUnop] = function(node, st, errors, context)
        local op = node.op
        checkexp(node.exp, st, errors)
        local texp = node.exp._type
        local loc = node.loc
        if op == "#" then
            if texp._tag ~= types.Array and texp._tag ~= types.String then
                checker.typeerror(errors, loc,
                    "trying to take the length of a %s instead of an array or string",
                    types.tostring(texp))
            end
            node._type = types.Integer()
        elseif op == "-" then
            if texp._tag ~= types.Integer and texp._tag ~= types.Float then
                checker.typeerror(errors, loc,
                    "trying to negate a %s instead of a number",
                    types.tostring(texp))
            end
            node._type = texp
        elseif op == "~" then
            if texp._tag ~= types.Integer then
                checker.typeerror(errors, loc,
                    "trying to bitwise negate a %s instead of an integer",
                    types.tostring(texp))
            end
            node._type = types.Integer()
        elseif op == "not" then
            if texp._tag ~= types.Boolean then
                -- Titan is being intentionaly restrictive here
                checker.typeerror(errors, loc,
                    "trying to negate a %s instead of a boolean",
                    types.tostring(texp))
            end
            node._type = types.Boolean()
        else
            error("invalid unary operation " .. op)
        end
    end,

    [ast.ExpConcat] = function(node, st, errors, context)
        for i, exp in ipairs(node.exps) do
            checkexp(exp, st, errors, types.String())
            -- always tries to coerce numbers to string
            exp = trytostr(exp)
            node.exps[i] = exp
            local texp = exp._type
            if texp._tag ~= types.String then
                checker.typeerror(errors, exp.loc,
                    "cannot concatenate with %s value", types.tostring(texp))
            end
        end
        node._type = types.String()
    end,

    [ast.ExpBinop] = function(node, st, errors, context)
        local op = node.op
        checkexp(node.lhs, st, errors)
        local tlhs = node.lhs._type
        checkexp(node.rhs, st, errors)
        local trhs = node.rhs._type
        local loc = node.loc
        if op == "==" or op == "~=" then
            if (tlhs._tag == types.Integer and trhs._tag == types.Float) or
               (tlhs._tag == types.Float   and trhs._tag == types.Integer) then
                checker.typeerror(errors, loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
            elseif not types.equals(tlhs, trhs) then
                checker.typeerror(errors, loc,
                    "cannot compare %s and %s with %s",
                    types.tostring(tlhs), types.tostring(trhs), op)
            end
            node._type = types.Boolean()
        elseif op == "<" or op == ">" or op == "<=" or op == ">=" then
            if (tlhs._tag == types.Integer and trhs._tag == types.Integer) or
               (tlhs._tag == types.Float   and trhs._tag == types.Float) or
               (tlhs._tag == types.String  and trhs._tag == types.String) then
               -- OK
            elseif (tlhs._tag == types.Integer and trhs._tag == types.Float) or
                   (tlhs._tag == types.Float   and trhs._tag == types.Integer) then
                checker.typeerror(errors, loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
            else
                checker.typeerror(errors, loc,
                    "cannot compare %s and %s with %s",
                    types.tostring(tlhs), types.tostring(trhs), op)
            end
            node._type = types.Boolean()
        elseif op == "+" or op == "-" or op == "*" or op == "%" or op == "//" then
            if not (tlhs._tag == types.Integer or tlhs._tag == types.Float) then
                checker.typeerror(errors, loc,
                    "left hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(tlhs))
            end
            if not (trhs._tag == types.Integer or trhs._tag == types.Float) then
                checker.typeerror(errors, loc,
                    "right hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(trhs))
            end
            -- tries to coerce to float if either side is float
            if tlhs._tag == types.Float or trhs._tag == types.Float then
                node.lhs = trycoerce(node.lhs, types.Float(), errors)
                tlhs = node.lhs._type
                node.rhs = trycoerce(node.rhs, types.Float(), errors)
                trhs = node.rhs._type
            end
            if tlhs._tag == types.Float and trhs._tag == types.Float then
                node._type = types.Float()
            elseif tlhs._tag == types.Integer and trhs._tag == types.Integer then
                node._type = types.Integer()
            else
                -- error
                node._type = types.Invalid()
            end
        elseif op == "/" or op == "^" then
            if tlhs._tag == types.Integer then
                -- always tries to coerce to float
                node.lhs = trycoerce(node.lhs, types.Float(), errors)
                tlhs = node.lhs._type
            end
            if trhs._tag == types.Integer then
                -- always tries to coerce to float
                node.rhs = trycoerce(node.rhs, types.Float(), errors)
                trhs = node.rhs._type
            end
            if tlhs._tag ~= types.Float then
                checker.typeerror(errors, loc,
                    "left hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(tlhs))
            end
            if trhs._tag ~= types.Float then
                checker.typeerror(errors, loc,
                    "right hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(trhs))
            end
            node._type = types.Float()
        elseif op == "and" or op == "or" then
            if tlhs._tag ~= types.Boolean then
                checker.typeerror(errors, loc,
                    "left hand side of logical expression is a %s instead of a boolean",
                    types.tostring(tlhs))
            end
            if trhs._tag ~= types.Boolean then
                checker.typeerror(errors, loc,
                    "right hand side of logical expression is a %s instead of a boolean",
                    types.tostring(trhs))
            end
            node._type = types.Boolean()
        elseif op == "|" or op == "&" or op == "<<" or op == ">>" then
            if tlhs._tag ~= types.Integer then
                checker.typeerror(errors, loc,
                    "left hand side of arithmetic expression is a %s instead of an integer",
                    types.tostring(tlhs))
            end
            if trhs._tag ~= types.Integer then
                checker.typeerror(errors, loc,
                    "right hand side of arithmetic expression is a %s instead of an integer",
                    types.tostring(trhs))
            end
            node._type = types.Integer()
        else
            error("invalid binary operation " .. op)
        end
    end,

    [ast.ExpCall] = function(node, st, errors, context)
        assert(node.exp._tag == ast.ExpVar, "function calls are first-order only!")
        local var = node.exp.var
        checkvar(var, st, errors)
        node.exp._type = var._type
        local fname = var._tag == ast.VarName and var.name or (var.exp.var.name .. "." .. var.name)
        if var._type._tag == types.Function then
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
                    checkexp(arg, st, errors, ptype)
                    ptype = ptype or arg._type
                    atype = args[i]._type
                end
                if not ptype then
                    ptype = atype
                end
                checkmatch("argument " .. i .. " of call to function '" .. fname .. "'", ptype, atype, errors, node.exp.loc)
            end
            if nargs ~= nparams then
                checker.typeerror(errors, node.loc,
                    "function %s called with %d arguments but expects %d",
                    fname, nargs, nparams)
            end
            assert(#ftype.rettypes == 1)
            node._type = ftype.rettypes[1]
        else
            checker.typeerror(errors, node.loc,
                "'%s' is not a function but %s",
                fname, types.tostring(var._type))
            for _, arg in ipairs(node.args.args) do
                checkexp(arg, st, errors)
            end
            node._type = types.Invalid()
        end
    end,

    [ast.ExpCast] = function(node, st, errors, context)
        node.target = typefromnode(node.target, st, errors)
        checkexp(node.exp, st, errors, node.target)
        if not types.coerceable(node.exp._type, node.target) and
          not types.equals(node.exp._type, node.target) then
            checker.typeerror(errors, node.loc,
                "cannot cast '%s' to '%s'",
                types.tostring(node.exp._type), types.tostring(node.target))
        end
        node._type = node.target
    end,
})

--
-- TopLevel
--

-- Typechecks a function body
--   node: TopLevelFunc AST node
--   st: symbol table
--   errors: list of compile-time errors
local function checkfunc(node, st, errors)
    st:add_symbol("$function", node) -- for return type
    local ptypes = node._type.params
    local pnames = {}
    for i, param in ipairs(node.params) do
        st:add_symbol(param.name, param)
        param._type = ptypes[i]
        if pnames[param.name] then
            checker.typeerror(errors, node.loc,
                "duplicate parameter '%s' in declaration of function '%s'",
                param.name, node.name)
        else
            pnames[param.name] = true
        end
    end
    assert(#node._type.rettypes == 1)
    local ret = st:with_block(checkstat, node.block, st, errors)
    if not ret and node._type.rettypes[1]._tag ~= types.Nil then
        checker.typeerror(errors, node.loc,
            "function can return nil but return type is not nil")
    end
end

-- Checks function bodies
--   prog: AST for the whole module
--   st: symbol table
--   errors: list of compile-time errors
local function checkbodies(prog, st, errors)
    for _, node in ipairs(prog) do
        if not node._ignore and
           node._tag == ast.TopLevelFunc then
            st:with_block(checkfunc, node, st, errors)
        end
    end
end

local function isconstructor(node)
    return node.var and node.var._decl and node.var._decl._tag == types.Record
end

-- Verify if an expression is constant
local function isconst(node)
    local tag = node._tag
    if tag == ast.ExpNil or
       tag == ast.ExpBool or
       tag == ast.ExpInteger or
       tag == ast.ExpFloat or
       tag == ast.ExpString then
        return true

    elseif tag == ast.ExpInitList then
        local const = true
        for _, field in ipairs(node.fields) do
            const = const and isconst(field.exp)
        end
        return const

    elseif tag == ast.ExpCall then
        if isconstructor(node.exp) then
            local const = true
            for _, arg in ipairs(node.args) do
                const = const and isconst(arg)
            end
            return const
        else
            return false
        end

    elseif tag == ast.ExpVar then
        return false

    elseif tag == ast.ExpConcat then
        local const = true
        for _, exp in ipairs(node.exps) do
            const = const and isconst(exp)
        end
        return const

    elseif tag == ast.ExpUnop then
        return isconst(node.exp)

    elseif tag == ast.ExpBinop then
        return isconst(node.lhs) and isconst(node.rhs)

    elseif tag == ast.ExpCast then
        return isconst(node.exp)

    else
        error("impossible")
    end
end

-- Return the name given the toplevel node
local function toplevel_name(node)
    local tag = node._tag
    if tag == ast.TopLevelImport then
        return node.localname
    elseif tag == ast.TopLevelVar then
        return node.decl.name
    elseif tag == ast.TopLevelFunc or
           tag == ast.TopLevelRecord then
        return node.name
    else
        error("impossible")
    end
end

-- Typecheck the toplevel node
local toplevel_visitor = util.make_visitor({
    [ast.TopLevelImport] = function(node, st, errors, loader)
        local modtype, errs = checker.checkimport(node.modname, loader)
        if modtype then
            node._type = modtype
            for _, err in ipairs(errs) do
                table.insert(errors, err)
            end
        else
            node._type = types.Nil()
            checker.typeerror(errors, node.loc,
                "problem loading module '%s': %s",
                node.modname, errs)
        end
    end,

    [ast.TopLevelVar] = function(node, st, errors)
        if node.decl.type then
            node._type = typefromnode(node.decl.type, st, errors)
            checkexp(node.value, st, errors, node._type)
            checkmatch("declaration of module variable " .. node.decl.name,
                       node._type, node.value._type, errors, node.loc)
        else
            checkexp(node.value, st, errors)
            node._type = node.value._type
        end
        if not isconst(node.value) then
            checker.typeerror(errors, node.value.loc,
                "top level variable initialization must be constant")
        end
    end,

    [ast.TopLevelFunc] = function(node, st, errors)
        if #node.rettypes ~= 1 then
            error("functions with 0 or 2+ return values are not yet implemented")
        end
        local ptypes = {}
        for _, pdecl in ipairs(node.params) do
            table.insert(ptypes, typefromnode(pdecl.type, st, errors))
        end
        local rettypes = {}
        for _, rt in ipairs(node.rettypes) do
            table.insert(rettypes, typefromnode(rt, st, errors))
        end
        node._type = types.Function(ptypes, rettypes)
    end,

    [ast.TopLevelRecord] = function(node, st, errors)
        local fields = {}
        for _, field in ipairs(node.fields) do
            local typ = typefromnode(field.type, st, errors)
            table.insert(fields, {type = typ, name = field.name})
        end
        node._type = types.Type(types.Record(node.name, fields))
    end,
})

-- Colect type information of toplevel nodes
--   prog: AST for the whole module
--   st: symbol table
--   errors: list of compile-time errors
--   annotates the top-level nodes with their types in a "_type" field
--   annotates whether a top-level declaration is duplicated with a "_ignore"
--   field
local function checktoplevel(prog, st, errors, loader)
    for _, node in ipairs(prog) do
        local name = toplevel_name(node)
        local dup = st:find_dup(name)
        if dup then
            checker.typeerror(errors, node.loc,
                "duplicate declaration for %s, previous one at line %d",
                name, dup.loc.line)
            node._ignore = true
        else
            toplevel_visitor(node, st, errors, loader)
            st:add_symbol(name, node)
        end
    end
end

function checker.checkimport(modname, loader)
    local ok, type_or_error, errors = loader(modname)
    if not ok then return nil, type_or_error end
    return type_or_error, errors
end

-- Entry point for the typechecker
--   prog: AST for the whole module
--   subject: the string that generated the AST
--   filename: the file name that contains the subject
--   loader: the module loader, a function from module name to its AST, code,
--   and filename or nil and an error
--
--   returns true if typechecking succeeds, or false and a list of type errors
--   found
--   annotates the AST with the types of its terms in "_type" fields
--   annotates duplicate top-level declarations with a "_ignore" boolean field
function checker.check(modname, prog, subject, filename, loader)
    loader = loader or function ()
        return nil, "you must pass a loader to import modules"
    end
    local st = symtab.new()
    local errors = {subject = subject, filename = filename}
    checktoplevel(prog, st, errors, loader)
    checkbodies(prog, st, errors)
    return types.makemoduletype(modname, prog), errors
end

return checker
