local checker = {}

local symtab = require 'titan-compiler.symtab'
local types = require 'titan-compiler.types'

local checkstat
local checkexp

local function typefromnode(typenode, errors)
    local tag = typenode._tag
    if tag == "Array" then
        return types.Array(typefromnode(typenode.subtype, errors))
    else
        local t = types.Base(typenode.name)
        if not t then
            table.insert(errors, "type name " .. typenode.name .. " is invalid")
            t = types.Integer
        end
        return t
    end
end

local function firstpass(ast, st, errors)
    for _, tlnode in ipairs(ast) do
        local tag = tlnode._tag
        local name
        if tag == "TopLevel_Func" then
            name = tlnode.name
            local ptypes = {}
            for _, pdecl in tlnode.params do
                table.insert(ptypes, typefromnode(pdecl.type, errors))
            end
            tlnode._type = types.Function(ptypes, typefromnode(tlnode.rettype, errors))
        else
            assert(tag == "TopLevel_Var")
            name = tlnode.decl.name
            tlnode._type = typefromnode(tlnode.decl.type, errors)
        end
        if st:find_dup(name) then
            table.insert(errors, "duplicate function or variable declaration for " .. name)
            tlnode.ignore = true
        else
            st:add_symbol(name, tlnode)
        end
    end
end

local function checkmatch(term, expected, found, errors)
    if not types.equals(expected, found) then
        local msg = "types in %s do not match, expected %s but found %s"
        table.insert(errors, string.format(msg, term, types.tostring(expected), types.tostring(found)))
    end
end

local function checkrepeat(node, st, errors)
    for _, stat in ipairs(node.block.stats) do
        checkstat(stat, st, errors)
    end
    checkexp(node.condition, st, errors, types.Boolean)
    return false
end

local function checkfor(node, st, errors)
    checkstat(node.decl, st, errors)
    local ftype = node.decl._type
    if not types.equals(ftype, types.Integer) and
        not types.equals(ftype, types.Float) then
        table.insert(errors, "type of for control variable " .. node.decl.name .. " must be integer or float")
        node.decl._type = types.Integer
        ftype = types.Integer
    end
    checkexp(node.start, st, errors, types.Integer)
    checkmatch("'for' start expression", ftype, node.start._type, errors)
    checkexp(node.finish, st, errors, types.Integer)
    checkmatch("'for' finish expression", ftype, node.finish._type, errors)
    if node.inc then
        checkexp(node.inc, st, errors, types.Integer)
        checkmatch("'for' step expression", ftype, node.inc._type, errors)
    end
    checkstat(node.block, st, errors)
    return false
end

local function checkblock(node, st, errors)
    local ret = false
    for _, stat in node.stats do
        ret = ret or checkstat(stat, st, errors)
    end
    return ret
end

function checkstat(node, st, errors)
    local tag = node._tag
    if tag == "Decl_Decl" then
        st:add_symbol(node.name, node)
        node._type = typefromnode(node.type, errors)
    elseif tag == "Stat_Decl" then
        checkstat(node.decl, st, errors)
        checkexp(node.exp, st, errors, node.decl._type)
        checkmatch("declaration of local variable " .. node.decl.name,
            node.decl._type, node.exp._type, errors)
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
        checkexp(node.exp, st, errors, node.var._type)
        checkmatch("assignment", node.var._type, node.exp._type, errors)
    elseif tag == "Stat_Call" then
        checkexp(node.callexp, st, errors)
    elseif tag == "Stat_Return" then
        local tret = st:find_symbol("$function")._type.ret
        checkexp(node.exp, st, errors, tret)
        checkmatch("return", tret, node.exp_type, errors)
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
        error("typechecking not implemented for node type " .. tag)
    end
    return false
end

function checkexp(node, st, errors, context)
    local tag = node._tag
    if tag == "Var_Name" then
        local decl = st:find_symbol(node.name) 
        if not decl then
            -- TODO generate better error messages when we have the line num
            local error = "variable '" .. node.name .. "' not declared"
            table.insert(errors, error)
            node._type = types.Integer
        elseif decl._tag == "TopLevel_Func" then
            table.insert(errors, "reference to function " .. node.name .. " outside of function call")
            node._type = types.Integer
        else
            node.decl = decl
            node._type = decl._type
        end
    elseif tag == "Var_Index" then
        checkexp(node.exp1, st, errors, context and types.Array(context))
        if not types.has_tag(node.exp1._type, "Array") then
            table.insert(errors, "array expression in indexing is not an array but " 
                .. types.tostring(node.exp1._type))
            node._type = types.Integer
        else
            node._type = node.exp1._type.elem
        end
        checkexp(node.exp2, st, errors, types.Integer)
        checkmatch("array indexing", types.Integer, node.exp2._type, errors)
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
            checkmatch("array initializer at position " .. i, etype, exp._type)
        end
    elseif tag == "Exp_Var" then
        checkexp(node.var, st, errors, context)
        node._type = node.var._type
    elseif tag == "Exp_Unop" then
        -- TODO: check kind of operation, maybe have different kinds of AST nodes?
    elseif tag == "Exp_Binop" then
        -- TODO: same here, separate AST nodes by kind of binary operation
    elseif tag == "Exp_Call" then
        -- TODO: lookup function, check args, _type is return type
    else
        error("typechecking not implemented for node type " .. tag)
    end
end

local function checkfunc(node, st, errors)
    st:add_symbol("$function", node) -- for return type
    for _, param in node.params do
        checkstat(param, st, errors)
    end
    -- TODO: check if all paths through the function have returned
    local ret = st:with_block(checkstat, node.block, st, errors)
    if not ret and not types.equals(node._type.ret, types.Nil) then
        table.insert(errors, "function can return nil but return type is not nil")
    end
end

local function secondpass(ast, st, errors)
    for _, tlnode in ipairs(ast) do
        if not tlnode.ignore then
            local tag = tlnode._tag
            if tag == "TopLevel_Func" then
                st:with_block(checkfunc, node, st, errors)
            else
                checkexp(tlnode.value, st, errors, tlnode._type)
            end
        end
    end
end

function checker.check(ast)
    local st = symtab.new()
    local errors = {}
    st:with_block(firstpass, ast, st, errors)
    st:with_block(secondpass, ast, st, errors)
    -- TODO return all error messages
    if #errors > 0 then
        return false, errors[1]
    end
    return true
end

return checker
