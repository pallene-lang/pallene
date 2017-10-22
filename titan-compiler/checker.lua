local checker = {}

local symtab = require "titan-compiler.symtab"
local types = require "titan-compiler.types"
local ast = require "titan-compiler.ast"
local util = require "titan-compiler.util"

local checkstat
local checkexp

local function typeerror(errors, msg, pos)
    local l, c = util.get_line_number(errors.subject, pos)
    msg = string.format("%s:%d:%d: type error: %s", errors.filename, l, c, msg)
    table.insert(errors, msg)
end

-- Converts an AST type declaration into a typechecker type
--   typenode: AST node
--   errors: list of compile-time errors
--   returns a type (from types.lua)
local function typefromnode(typenode, errors)
    local tag = typenode._tag
    if tag == "Type_Array" then
        return types.Array(typefromnode(typenode.subtype, errors))
    elseif tag == "Type_Basic" then
        local t = types.Base(typenode.name)
        if not t then
            typeerror(errors, "type name " .. typenode.name .. " is invalid", typenode._pos)
            t = types.Integer
        end
        return t
    else
        error("invalid node tag " .. tag)
    end
end

-- Wraps an expression node in a coercion to integer if
-- type of node is float
--   node: expression node
--   returns wrapped node, or original
local function trytoint(node)
    if types.equals(node._type, types.Float) then
        local n = ast.Exp_ToInt(node._pos, node)
        n._type = types.Integer
        return n
    else
        return node
    end
end

-- Wraps an expression node in a coercion to float if
-- type of node is integer
--   node: expression node
--   returns wrapped node, or original
local function trytofloat(node)
    if types.equals(node._type, types.Integer) then
        local n = ast.Exp_ToFloat(node._pos, node)
        n._type = types.Float
        return n
    else
        return node
    end
end

-- Wraps an expression node in a coercion to string
-- type of node is not string already
--   node: expression node
--   returns wrapped node, or original
local function trytostr(node)
    local typ = node._type
    if types.equals(typ, types.Float) or types.equals(typ, types.Integer) then
        local n = ast.Exp_ToStr(node._pos, node)
        n._type = types.String
        return n
    else
        return node
    end
end

-- Wraps an expression node in a coercion to boolean
-- type of node is not boolean already
--   node: expression node
--   returns wrapped node, or original
local function trytobool(node)
    if not types.equals(node._type, types.Boolean) then
        local n = ast.Exp_ToBool(node._pos, node)
        n._type = types.Boolean
        return n
    else
        return node
    end
end

-- tries to coerce node to target numeric type
--    node: expression node
--    target: target type
--    returns node wrapped in a coercion, or original node
local function trycoerce(node, target)
    if types.equals(target, types.Integer) then
        return trytoint(node)
    elseif types.equals(target, types.Float) then
        return trytofloat(node)
    else
        return node
    end
end

-- First typecheck pass over the module, typecheks module variables
--   ast: AST for the whole module
--   st: symbol table
--   errors: list of compile-time errors
--   annotates the top-level nodes with their types in a "_type" field
--   annotates whether a top-level declaration is duplicated with a "_ignore" field
local function firstpass(ast, st, errors)
    for _, tlnode in ipairs(ast) do
        local name
        if tlnode._tag == "TopLevel_Var" then
            name = tlnode.decl.name
            if tlnode.decl.type then
                tlnode._type = typefromnode(tlnode.decl.type, errors)
                checkexp(tlnode.value, st, errors, tlnode._type)
            else
                checkexp(tlnode.value, st, errors)
                tlnode._type = tlnode.value._type
            end
            tlnode._lin = util.get_line_number(errors.subject, tlnode._pos)
            if st:find_dup(name) then
                typeerror(errors, "duplicate variable declaration for " .. name, tlnode._pos)
                tlnode._ignore = true
            else
                st:add_symbol(name, tlnode)
            end
        end
    end
end


-- Second typecheck pass over the module, collects type information
-- for top-level functions
--   ast: AST for the whole module
--   st: symbol table
--   errors: list of compile-time errors
--   annotates the top-level nodes with their types in a "_type" field
--   annotates whether a top-level declaration is duplicated with a "_ignore" field
local function secondpass(ast, st, errors)
    for _, tlnode in ipairs(ast) do
        local name
        if tlnode._tag == "TopLevel_Func" then
            name = tlnode.name
            local ptypes = {}
            for _, pdecl in ipairs(tlnode.params) do
                table.insert(ptypes, typefromnode(pdecl.type, errors))
            end
            tlnode._type = types.Function(ptypes, typefromnode(tlnode.rettype, errors))
            if st:find_dup(name) then
                typeerror(errors, "duplicate function or variable declaration for " .. name, tlnode._pos)
                tlnode._ignore = true
            else
                st:add_symbol(name, tlnode)
            end
        end
    end
end

-- Checks if two types are the same, and logs an error message otherwise
--   term: string describing what is being compared
--   expected: type that is expected
--   found: type that was actually present
--   errors: list of compile-time errors
--   pos: position of the term that is being compared
local function checkmatch(term, expected, found, errors, pos)
    if not types.equals(expected, found) then
        local msg = "types in %s do not match, expected %s but found %s"
        msg = string.format(msg, term, types.tostring(expected), types.tostring(found))
        typeerror(errors, msg, pos)
    end
end

-- Typechecks a repeat/until statement
--   node: Stat_Repeat AST node
--   st: symbol table
--   errors: list of compile-time errors
--   returns whether statement always returns from its function (always false for repeat/until)
local function checkrepeat(node, st, errors)
    for _, stat in ipairs(node.block.stats) do
        checkstat(stat, st, errors)
    end
    checkexp(node.condition, st, errors, types.Boolean)
    return false
end

-- Typechecks a for loop statement
--   node: Stat_For AST node
--   st: symbol table
--   errors: list of compile-time errors
--   returns whether statement always returns from its function (always false for 'for' loop)
local function checkfor(node, st, errors)
    local ftype
    if node.decl.type then
      checkstat(node.decl, st, errors)
      ftype = node.decl._type
      if not types.equals(ftype, types.Integer) and
        not types.equals(ftype, types.Float) then
        typeerror(errors, "type of for control variable " .. node.decl.name .. " must be integer or float", node.decl._pos)
        node.decl._type = types.Integer
        ftype = types.Integer
      end
      checkexp(node.start, st, errors, ftype)
      node.start = trycoerce(node.start, ftype)
    else
      checkexp(node.start, st, errors)
      ftype = node.start._type
      node.decl._type = ftype
      checkstat(node.decl, st, errors)
      if not types.equals(ftype, types.Integer) and
        not types.equals(ftype, types.Float) then
        typeerror(errors, "type of for control variable " .. node.decl.name .. " must be integer or float", node.decl._pos)
        node.decl._type = types.Integer
        ftype = types.Integer
      end
    end
    checkmatch("'for' start expression", ftype, node.start._type, errors, node.start._pos)
    checkexp(node.finish, st, errors, ftype)
    node.finish = trycoerce(node.finish, ftype)
    checkmatch("'for' finish expression", ftype, node.finish._type, errors, node.finish._pos)
    if node.inc then
        checkexp(node.inc, st, errors, ftype)
        node.inc = trycoerce(node.inc, ftype)
        checkmatch("'for' step expression", ftype, node.inc._type, errors, node.inc._pos)
    end
    checkstat(node.block, st, errors)
    return false
end

-- Typechecks a block statement
--   node: Stat_Block AST node
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

-- Typechecks a stament or declararion
--   node: A Decl_Decl or Stat_* AST node
--   st: symbol table
--   errors: list of compile-time errors
--   returns whether statement always returns from its function (always false for repeat/until)
function checkstat(node, st, errors)
    local tag = node._tag
    if tag == "Decl_Decl" then
        st:add_symbol(node.name, node)
        node._type = node._type or typefromnode(node.type, errors)
    elseif tag == "Stat_Decl" then
        if node.decl.type then
          checkstat(node.decl, st, errors)
          checkexp(node.exp, st, errors, node.decl._type)
        else
          checkexp(node.exp, st, errors)
          node.decl._type = node.exp._type
          checkstat(node.decl, st, errors)
        end
        node.exp = trycoerce(node.exp, node.decl._type)
        checkmatch("declaration of local variable " .. node.decl.name,
            node.decl._type, node.exp._type, errors, node.decl._pos)
    elseif tag == "Stat_Block" then
        return st:with_block(checkblock, node, st, errors)
    elseif tag == "Stat_While" then
        checkexp(node.condition, st, errors, types.Boolean)
        st:with_block(checkstat, node.block, st, errors)
    elseif tag == "Stat_Repeat" then
        st:with_block(checkrepeat, node, st, errors)
    elseif tag == "Stat_For" then
        st:with_block(checkfor, node, st, errors)
    elseif tag == "Stat_Assign" then
        checkexp(node.var, st, errors)
        -- mark this variable as assigned to
        if node.var._tag == "Var_Name" then
          node.var._decl._assigned = true
        end
        checkexp(node.exp, st, errors, node.var._type)
        node.exp = trycoerce(node.exp, node.var._type)
        if node.var._tag ~= "Var_Index" or not types.equals(node.exp._type, types.Nil) then
            checkmatch("assignment", node.var._type, node.exp._type, errors, node.var._pos)
        end
    elseif tag == "Stat_Call" then
        checkexp(node.callexp, st, errors)
    elseif tag == "Stat_Return" then
        local tret = st:find_symbol("$function")._type.ret
        checkexp(node.exp, st, errors, tret)
        node.exp = trycoerce(node.exp, tret)
        node._type = tret
        checkmatch("return", tret, node.exp._type, errors, node.exp._pos)
        node._type = tret
        return true
    elseif tag == "Stat_If" then
        local ret = true
        for _, thn in ipairs(node.thens) do
            checkexp(thn.condition, st, errors, types.Boolean)
            ret = checkstat(thn.block, st, errors) and ret
        end
        if node.elsestat then
            ret = checkstat(node.elsestat, st, errors) and ret
        end
        return ret
    else
        error("invalid node tag " .. tag)
    end
    return false
end

-- Typechecks an expression
--   node: Var_* or Exp_* AST node
--   st: symbol table
--   errors: list of compile-time errors
--   context: expected type for this expression, if applicable
--   annotates the node with its type in a "_type" field
function checkexp(node, st, errors, context)
    -- TODO coercions integer <-> float
    local tag = node._tag
    if tag == "Var_Name" then
        local decl = st:find_symbol(node.name)
        if not decl then
            local msg = "variable '" .. node.name .. "' not declared"
            typeerror(errors, msg, node._pos)
            node._type = types.Integer
        elseif decl._tag == "TopLevel_Func" then
            typeerror(errors, "reference to function " .. node.name .. " outside of function call", decl._pos)
            node._type = types.Integer
        else
            decl._used = true
            node._decl = decl
            node._type = decl._type
        end
    elseif tag == "Var_Index" then
        local l, _ = util.get_line_number(errors.subject, node._pos)
        node._lin = l
        checkexp(node.exp1, st, errors, context and types.Array(context))
        if not types.has_tag(node.exp1._type, "Array") then
            typeerror(errors, "array expression in indexing is not an array but "
                .. types.tostring(node.exp1._type), node.exp1._pos)
            node._type = types.Integer
        else
            node._type = node.exp1._type.elem
        end
        checkexp(node.exp2, st, errors, types.Integer)
        checkmatch("array indexing", types.Integer, node.exp2._type, errors, node.exp2._pos)
    elseif tag == "Exp_Nil" then
        node._type = types.Nil
    elseif tag == "Exp_Bool" then
        node._type = types.Boolean
    elseif tag == "Exp_Integer" then
        node._type = types.Integer
    elseif tag == "Exp_Float" then
        node._type = types.Float
    elseif tag == "Exp_String" then
        node._type = types.String
    elseif tag == "Exp_Table" then
        local econtext = context and context.elem
        local etypes = {}
        for _, exp in ipairs(node.exps) do
            checkexp(exp, st, errors, econtext)
            table.insert(etypes, exp._type)
        end
        local etype = etypes[1] or (context and context.elem) or types.Integer
        node._type = types.Array(etype)
        for i, exp in ipairs(node.exps) do
            checkmatch("array initializer at position " .. i, etype, exp._type, errors, exp._pos)
        end
    elseif tag == "Exp_Var" then
        checkexp(node.var, st, errors, context)
        node._type = node.var._type
    elseif tag == "Exp_Unop" then
        local op = node.op
        checkexp(node.exp, st, errors)
        local texp = node.exp._type
        local pos = node._pos
        if op == "#" then
            if not types.has_tag(texp, "Array") and not types.equals(texp, types.String) then
                typeerror(errors, "trying to take the length of a " .. types.tostring(texp) .. " instead of an array or string", pos)
            end
            node._type = types.Integer
        elseif op == "-" then
            if not types.equals(texp, types.Integer) and not types.equals(texp, types.Float) then
                typeerror(errors, "trying to negate a " .. types.tostring(texp) .. " instead of a number", pos)
            end
            node._type = texp
        elseif op == "~" then
            node.exp = trytoint(node.exp)
            texp = node.exp._type
            if not types.equals(texp, types.Integer) then
                typeerror(errors, "trying to bitwise negate a " .. types.tostring(texp) .. " instead of an integer", pos)
            end
            node._type = types.Integer
        elseif op == "not" then
            node._type = types.Boolean
        else
            error("invalid unary operation " .. op)
        end
    elseif tag == "Exp_Concat" then
        for i, exp in ipairs(node.exps) do
            checkexp(exp, st, errors, types.String)
            -- always tries to coerce to string
            exp = trytostr(exp)
            node.exps[i] = exp
            local texp = exp._type
            if not types.equals(texp, types.String) then
                typeerror(errors, "cannot concatenate with " .. types.tostring(texp) .. " value", exp._pos)
            end
        end
        node._type = types.String
    elseif tag == "Exp_Binop" then
        local op = node.op
        checkexp(node.lhs, st, errors)
        local tlhs = node.lhs._type
        checkexp(node.rhs, st, errors)
        local trhs = node.rhs._type
        local pos = node._pos
        if op == "==" or op == "~=" then
            -- tries to coerce integer to float if either side is float
            if types.equals(tlhs, types.Float) or types.equals(trhs, types.Float) then
                node.lhs = trytofloat(node.lhs)
                tlhs = node.lhs._type
                node.rhs = trytofloat(node.rhs)
                trhs = node.rhs._type
            end
            if not types.equals(tlhs, trhs) then
                typeerror(errors, "trying to compare values of different types: " ..
                    types.tostring(tlhs) .. " and " .. types.tostring(trhs), pos)
            end
            node._type = types.Boolean
        elseif op == "<" or op == ">" or op == "<=" or op == ">=" then
            -- tries to coerce integer to float if either side is float
            if types.equals(tlhs, types.Float) or types.equals(trhs, types.Float) then
                node.lhs = trytofloat(node.lhs)
                tlhs = node.lhs._type
                node.rhs = trytofloat(node.rhs)
                trhs = node.rhs._type
            end
            if not types.equals(tlhs, types.Integer) and not types.equals(tlhs, types.Float) then
                typeerror(errors, "left hand side of relational expression is a " .. types.tostring(tlhs) .. " instead of a number", pos)
            end
            if not types.equals(trhs, types.Integer) and not types.equals(trhs, types.Float) then
                typeerror(errors, "right hand side of relational expression is a " .. types.tostring(trhs) .. " instead of a number", pos)
            end
            node._type = types.Boolean
        elseif op == "+" or op == "-" or op == "*" or op == "%" or op == "//" then
            -- tries to coerce integer to float if other side is float
            if types.equals(tlhs, types.Float) or types.equals(trhs, types.Float) then
                node.lhs = trytofloat(node.lhs)
                tlhs = node.lhs._type
                node.rhs = trytofloat(node.rhs)
                trhs = node.rhs._type
            end
            if not (types.equals(tlhs, types.Integer) or types.equals(tlhs, types.Float)) then
                typeerror(errors, "left hand side of arithmetic expression is a " .. types.tostring(tlhs) .. " instead of a number", pos)
            end
            if not (types.equals(trhs, types.Integer) or types.equals(trhs, types.Float)) then
                typeerror(errors, "right hand side of arithmetic expression is a " .. types.tostring(trhs) .. " instead of a number", pos)
            end
            if types.equals(tlhs, types.Float) or types.equals(trhs, types.Float) then
                node._type = types.Float
            else
                node._type = types.Integer
            end
        elseif op == "/" or op == "^" then
            -- always coerces to float if one side is integer
            node.lhs = trytofloat(node.lhs)
            tlhs = node.lhs._type
            node.rhs = trytofloat(node.rhs)
            trhs = node.rhs._type
            if not types.equals(tlhs, types.Integer) and not types.equals(tlhs, types.Float) then
                typeerror(errors, "left hand side of arithmetic expression is a " .. types.tostring(tlhs) .. " instead of a number", pos)
            end
            if not types.equals(trhs, types.Integer) and not types.equals(trhs, types.Float) then
                typeerror(errors, "right hand side of arithmetic expression is a " .. types.tostring(trhs) .. " instead of a number", pos)
            end
            node._type = types.Float
        elseif op == "and" or op == "or" then
            -- tries to coerce integer to float if other side is float
            if types.equals(tlhs, types.Float) or types.equals(trhs, types.Float) then
              node.lhs = trytofloat(node.lhs)
              tlhs = node.lhs._type
              node.rhs = trytofloat(node.rhs)
              trhs = node.rhs._type
            end
            -- coerces other side to boolean if either side is boolean
            if types.equals(tlhs, types.Boolean) or types.equals(trhs, types.Boolean) then
                node.lhs = trytobool(node.lhs)
                tlhs = node.lhs._type
                node.rhs = trytobool(node.rhs)
                trhs = node.rhs._type
            end
            if not types.equals(tlhs, trhs) then
              typeerror(errors, "left hand side of logical expression is a " ..
               types.tostring(tlhs) .. " but right hand side is a " ..
               types.tostring(trhs), pos)
            end
            node._type = tlhs
        elseif op == "|" or op == "&" or op == "<<" or op == ">>" then
            -- always tries to coerce to integer
            node.lhs = trytoint(node.lhs)
            tlhs = node.lhs._type
            node.rhs = trytoint(node.rhs)
            trhs = node.rhs._type
            if not types.equals(tlhs, types.Integer) then
                typeerror(errors, "left hand side of arithmetic expression is a " .. types.tostring(tlhs) .. " instead of a number", pos)
            end
            if not types.equals(trhs, types.Integer) then
                typeerror(errors, "right hand side of arithmetic expression is a " .. types.tostring(trhs) .. " instead of a number", pos)
            end
            node._type = types.Integer
        else
            error("invalid binary operation " .. op)
        end
    elseif tag == "Exp_Call" then
        assert(node.exp._tag == "Exp_Var", "function calls are first-order only!")
        local fname = node.exp.var.name
        local func =  st:find_symbol(fname)
        if func then
            local ftype = func._type
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
                    args[i] = trycoerce(args[i], ptype)
                    atype = args[i]._type
                end
                if not ptype then
                    ptype = atype
                end
                checkmatch("argument " .. i .. " of call to function " .. fname, ptype, atype, errors, node.exp._pos)
            end
            if nargs ~= nparams then
                typeerror(errors, "function " .. fname .. " called with " .. nargs ..
                    " arguments but expects " .. nparams, node._pos)
            end
            node._type = ftype.ret
        else
            typeerror(errors, "function " .. fname .. " not found", node._pos)
            for _, arg in ipairs(node.args.args) do
                checkexp(arg, st, errors)
            end
            node._type = types.Integer
        end
    else
        error("invalid node tag " .. tag)
    end
end

-- Typechecks a function body
--   node: TopLevel_Func AST node
--   st: symbol table
--   errors: list of compile-time errors
local function checkfunc(node, st, errors)
    local l, _ = util.get_line_number(errors.subject, node._pos)
    node._lin = l
    st:add_symbol("$function", node) -- for return type
    for _, param in ipairs(node.params) do
        checkstat(param, st, errors)
    end
    local ret = st:with_block(checkstat, node.block, st, errors)
    if not ret and not types.equals(node._type.ret, types.Nil) then
        typeerror(errors, "function can return nil but return type is not nil", node._pos)
    end
end

-- Third typechecking pass over the module, checks function bodies
--   ast: AST for the whole module
--   st: symbol table
--   errors: list of compile-time errors
local function thirdpass(ast, st, errors)
    for _, tlnode in ipairs(ast) do
        if not tlnode._ignore then
            local tag = tlnode._tag
            if tag == "TopLevel_Func" then
                st:with_block(checkfunc, tlnode, st, errors)
            end
        end
    end
end

-- Entry point for the typechecker
--   ast: AST for the whole module
--   subject: the string that generated the AST
--   filename: the file name that contains the subject
--   returns true if typechecking succeeds, or false and a list of type errors found
--   annotates the AST with the types of its terms in "_type" fields
--   annotates duplicate top-level declarations with a "_ignore" boolean field
function checker.check(ast, subject, filename)
    local st = symtab.new()
    local errors = {subject = subject, filename = filename}
    firstpass(ast, st, errors)
    secondpass(ast, st, errors)
    thirdpass(ast, st, errors)
    if #errors > 0 then
        return false, table.concat(errors, "\n")
    end
    return true
end

return checker
