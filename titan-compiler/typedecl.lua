-- Create a constructor for each type
-- See also: ast.lua

return function(prefix, types)
    local constructors = {}
    for typename, conss in pairs(types) do
        for consname, fields in pairs(conss) do
            local tag = prefix .. "." .. consname
            constructors[consname] = function(...)
                local args = table.pack(...)
                if args.n ~= #fields then
                    error("missing arguments for " .. consname)
                end
                local node = { _tag = tag }
                for i, field in ipairs(fields) do
                    node[field] = args[i]
                end
                return node
            end
        end
    end
    return constructors
end
