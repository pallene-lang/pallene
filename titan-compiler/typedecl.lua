-- Create a constructor for each type
-- See also: ast.lua
return function(types)
    local constructors = {}
    for typename, conss in pairs(types) do
        for consname, fields in pairs(conss) do
            local tag = typename .. "_" .. consname
            constructors[tag] = function(pos, ...)
                local args = table.pack(...)
                if args.n ~= #fields then
                    error("missing arguments for " .. tag)
                end
                local node = { _tag = tag, _pos = pos }
                for i, field in ipairs(fields) do
                    assert(field ~= "_tag")
                    node[field] = args[i]
                end
                return node
            end
        end
    end
    return constructors
end
