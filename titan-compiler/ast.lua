local ast = {}

-- Declarations of union types
local types = {}

types.Type = {
    Basic   = {'name'},
    Array   = {'subtype'},
}

types.TopLevel = {
    Func    = {'islocal', 'name', 'params', 'rettype', 'block'},
    Var     = {'islocal', 'decl', 'value'},
}

types.Decl = {
    Decl    = {'name', 'type'},
}

types.Stat = {
    Block   = {'stats'},
    While   = {'condition', 'block'},
    Repeat  = {'block', 'condition'},
    If      = {'thens', 'elsestat'},
    For     = {'name', 'start', 'end', 'inc', 'block'},
    Assign  = {'var', 'exp'},
    Decl    = {'decl'},
    Call    = {'callexp'},
    Return  = {'exp'},
}

types.Then = {
    Then    = {'exp', 'block'},
}

types.Var = {
    Name    = {'name'},
    Index   = {'exp1', 'exp2'},
}

types.Exp = {
    Value   = {'value'},
    Table   = {'exps'},
    Call    = {'exp', 'args'},
    Var     = {'var'},
    Unop    = {'op', 'exp'},
    Binop   = {'lhs', 'op', 'rhs'},
}

types.Args = {
    Func    = {'args'},
    Method  = {'method', 'args'},
}

-- Create a function for each type constructor
for typename, conss in pairs(types) do
    for consname, fields in pairs(conss) do
        local tag = typename .. '_' .. consname

        local mt = { __index = {
            foreach = function(self, visitor, ...)
                assert(type(visitor) == 'function')
                for _, field in pairs(fields) do
                    local ok, err = visitor(self[field], ...)
                    if not ok then return false, err end
                end
                return true
            end,
        }}

        ast[tag] = function(...)
            local args = table.pack(...)
            if args.n ~= #fields then
                error('missing arguments for ' .. tag)
            end
            local node = { _tag = tag }
            setmetatable(node, mt)
            for i, field in ipairs(fields) do
                assert(field ~= '_tag')
                node[field] = args[i]
            end
            return node
        end
    end
end

return ast
