local checker = {}

local symtab = require 'titan-compiler.symtab'

local function visit_children(f, node, ...)
    local tag = node._tag
    if not tag then -- the node is an array
        for _, child in ipairs(node) do
            f(child, ...)
        end
    else
        for _, child in node:children() do
            f(child, ...)
        end
    end
end

local function bindvars(node, st, errors)
    if not node or type(node) ~= "table" then
        return
    end

    local tag = node._tag
    if tag == "TopLevel_Func" then
        st:add_symbol(node.name, node)
        st:with_block(visit_children, node, st, errors)

    elseif tag == "Decl_Decl" then
        st:add_symbol(node.name, node)

    elseif tag == "Stat_Block" or
           tag == "Stat_For" then
        st:with_block(visit_children, node, st, errors)

    elseif tag == "Var_Name" then
        node.decl = st:find_symbol(node.name)
        if not node.decl then
            -- TODO generate better error messages when we have the line num
            local error = "variable '" .. node.name .. "' not declared"
            table.insert(errors, error)
        end

    else
        visit_children(node, st, errors)
    end
end

function checker.check(ast)
    local st = symtab.new()
    local errors = {}
    st:with_block(bindvars, ast, st, errors)
    -- TODO return all error messages
    if #errors > 0 then
        return false, errors[1]
    end
    return true
end

return checker
