local checker = {}

local symtab = require 'titan-compiler.symtab'

local function bindvars(node, st, errors)
    if not node or type(node) ~= "table" then
        return
    end

    local function bindvars_children()
        for _, child in node:children() do
            bindvars(child, st, errors)
        end
    end

    local tag = node._tag
    if not tag then -- the node is an array
        for _, elem in ipairs(node) do
            bindvars(elem, st, errors)
        end

    elseif tag == "TopLevel_Func" then
        st:add_symbol(node.name, node)
        st:with_block(bindvars_children)

    elseif tag == "Decl_Decl" then
        st:add_symbol(node.name, node)

    elseif tag == "Stat_Block" then
        st:with_block(bindvars_children)

    elseif tag == "Var_Name" then
        node.decl = st:find_symbol(node.name)
        if not node.decl then
            -- TODO generate better error messages when we have the line num
            local error = "variable '" .. node.name .. "' not declared"
            table.insert(errors, error)
        end

    else
        bindvars_children()
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
