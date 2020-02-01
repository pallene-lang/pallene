-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local typedecl = {}

-- Unique tag names:
--
-- We keep track of all the type tags that we define, so that no two
-- constructors attempt to use the same type tag.

local existing_tags = {}

local function is_valid_name_component(s)
    -- In particular, this rules out the separator character "."
    return string.match(s, "[A-Za-z_][A-Za-z_0-9]*")
end

local function make_tag(mod_name, type_name, cons_name)
    assert(is_valid_name_component(mod_name))
    assert(is_valid_name_component(type_name))
    assert(is_valid_name_component(cons_name))
    local tag = mod_name .. "." .. type_name .. "." .. cons_name
    if existing_tags[tag] then
        error("tag name '" .. tag .. "' is already being used")
    else
        existing_tags[tag] = true
    end
    return tag
end

-- Create a properly-namespaced algebraic datatype. Objects belonging to this
-- type can be pattern matched by inspecting their _tag field. See ast.lua and
-- types.lua for usage examples.
--
-- @param module Module table where the type is being defined
-- @param mod_name Name of the type's module (only used by tostring)
-- @param type_name Name of the type
-- @param constructors Table describing the constructors of the ADT.
function typedecl.declare(module, mod_name, type_name, constructors)
    module[type_name] = {}
    for cons_name, fields in pairs(constructors) do
        local tag = make_tag(mod_name, type_name, cons_name)
        local function cons(...)
            local args = table.pack(...)
            if args.n ~= #fields then
                error("wrong number of arguments for " .. cons_name)
            end
            local node = { _tag = tag }
            for i, field in ipairs(fields) do
                node[field] = args[i]
            end
            return node
        end
        module[type_name][cons_name] = cons
    end
end

return typedecl
