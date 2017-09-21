local checker = {}

local symtab = require 'titan-compiler.symtab'

local function bindvars(node, st)
    if not node or type(node) ~= "table" then
        return true
    end

    local tag = node._tag
    if not tag then -- the node is an array
        for _, elem in ipairs(node) do
            local ok, err = bindvars(elem, st)
            if not ok then return false, err end
        end

    elseif tag == "TopLevel_Func" then
        st:add_symbol(node.name, node)
        st:open_block()
        local ok, err = node:foreach(bindvars, st)
        if not ok then return false, err end
        st:close_block()

    elseif tag == "Decl_Decl" then
        st:add_symbol(node.name, node)

    elseif tag == "Stat_Block" then
        st:open_block()
        local ok, err = node:foreach(bindvars, st)
        if not ok then return false, err end
        st:close_block()

    elseif tag == "Var_Name" then
        node.decl = st:find_symbol(node.name)
        if not node.decl then
            -- XXX generate better error messages when we have the line num
            return false, "variable '" .. node.name .. "' not declared"
        end

    else
        local ok, err = node:foreach(bindvars, st)
        if not ok then return false, err end
    end
    return true
end

function checker.check(ast)
    local st = symtab.new()
    st:open_block()
    local ok, err = bindvars(ast, st)
    if not ok then return false, err end
    return true
end

return checker
