-- Create a constructor for each type
-- See also: ast.lua

local function fill(node, args, fields, start)
    for i, field in ipairs(fields) do
        node[field] = args[i + start]
    end
end

return function(oblfields, prefix, types)
    oblfields = oblfields or {}
    local constructors = {}
    for typename, conss in pairs(types) do
        for consname, fields in pairs(conss) do
            constructors[consname] = function(...)
                local args = table.pack(...)
                if args.n ~= #oblfields + #fields then
                    error("missing arguments for " .. consname)
                end
                local node = { _tag = prefix .. consname }
                fill(node, args, oblfields, 0)
                fill(node, args, fields, #oblfields)
                return node
            end
        end
    end
    return constructors
end
