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
    While   = {'exp', 'block'},
    Repeat  = {'block', 'exp'},
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
    Index   = {'exp', 'exp'},
}

types.Exp = {
    Nil     = {},
    Bool    = {'bool'},
    Integer = {'integer'},
    Float   = {'float'},
    String  = {'string'},
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
    ast[typename] = {}
    for consname, fields in pairs(conss) do
        ast[typename][consname] = function(...)
            local args = table.pack(...)
            -- print('>', typename .. '.' .. consname, ...)
            if args.n ~= #fields then
                error('missing arguments for ' .. typename .. '.' .. consname)
            end
            local value = {_typename = typename, _tag = consname}
            for i, field in ipairs(fields) do
                assert(field ~= '_typename')
                assert(field ~= '_tag')
                value[field] = args[i]
            end
            return value
        end
    end
end

return ast
