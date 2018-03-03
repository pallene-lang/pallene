-- Create a constructor for each type
-- See also: ast.lua and types.lua

local typedecl = {}

local names = setmetatable({}, {__mode = 'v'})

function typedecl.decl(types)
    local constructors = {}
    for typename, conss in pairs(types) do
        for consname, fields in pairs(conss) do
            assert(not names[consname], "constructor already exists")
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
            constructors[consname] = cons
            names[cons] = consname
        end
    end
    return constructors
end

function typedecl.tostring(cons)
    return names[cons]
end

return typedecl
