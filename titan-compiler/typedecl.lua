-- This module lets us create algebric types that can be pattern matched.
-- See ast.lua and types.lua for usage examples.

local typedecl = {}

local names = setmetatable({}, {__mode = 'v'})

function typedecl.declare(module, modname, typename, constructors)
    module[typename] = {}
    for consname, fields in pairs(constructors) do
        local function cons(...)
            local args = table.pack(...)
            if args.n ~= #fields then
                error("missing arguments for " .. consname)
            end
            local node = { _tag = cons }
            for i, field in ipairs(fields) do
                node[field] = args[i]
            end
            return node
        end
        module[typename][consname] = cons
        names[cons] = modname .. '.' .. typename .. '.' .. consname
    end
end

function typedecl.tostring(cons)
    return names[cons]
end

return typedecl
