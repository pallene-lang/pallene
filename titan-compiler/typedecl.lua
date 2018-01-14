-- Create a constructor for each type
-- See also: ast.lua

local function fill(node, args, fields, start)
    for i, field in ipairs(fields) do
        node[field] = args[i + start]
    end
end

return function(oblfields, useprefix, types)
    oblfields = oblfields or {}
    local constructors = {}
    for typename, conss in pairs(types) do
        for consname, fields in pairs(conss) do
            local prefix = useprefix and (typename .. "_") or ""
            local tag = prefix .. consname
            constructors[tag] = function(...)
                local args = table.pack(...)
                if args.n ~= #oblfields + #fields then
                    error("missing arguments for " .. tag)
                end
                local node = { _tag = tag }
                fill(node, args, oblfields, 0)
                fill(node, args, fields, #oblfields)
                return node
            end
        end
    end
    return constructors
end
