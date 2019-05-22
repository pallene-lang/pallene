local typedecl = {}

local names = setmetatable({}, {__mode = "k"})

-- Create a properly-namespaced algebraic datatype. Objects belonging to this
-- type can be pattern matched by inspecting their _tag field. See ast.lua and
-- types.lua for usage examples.
--
-- @param module Module table where the type is being defined
-- @param modname Name of the type's module (only used by tostring)
-- @param typename Name of the type
-- @param constructors Table describing the constructors of the ADT.
function typedecl.declare(module, mod_name, type_name, constructors)
    module[type_name] = {}
    for cons_name, fields in pairs(constructors) do
        local function cons(...)
            local args = table.pack(...)
            if args.n ~= #fields then
                error("wrong number of arguments for " .. cons_name)
            end
            local node = { _tag = cons }
            for i, field in ipairs(fields) do
                node[field] = args[i]
            end
            return node
        end
        module[type_name][cons_name] = cons
        names[cons] = mod_name .. "." .. type_name .. "." .. cons_name
    end
end

-- Printable representation of a type tag, for printf debugging
function typedecl.tostring(cons)
    return names[cons]
end

return typedecl
