-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- TAGGED UNIONS
-- =============
-- Pallene's compiler uses many tagged unions / variant records.
-- This module helps create and use such tagged unions.
--
-- Example usage: the code below defines a new tagged union in the "ast" namespace.
--
--     local tagged_union = require 'pallene.tagged_union'
--     local define_union = tagged_union.in_namespace(ast, "ast")
--
--     define_union("Var", {
--         Name    = {"loc", "name"},
--         Bracket = {"loc", "t", "k"},
--         Dot     = {"loc", "exp", "name"}
--     })
--
-- It generates suitable constructor functions:
--
--     node = ast.Var.Name(loc, name)
--
-- The constructor produces a variant record containing a _tag field:
--
--     { _tag = "ast.Var.Name", loc = loc, name = name }
--

local tagged_union = {}

-- These associative arrays ensure that type tags are unique.
-- They also compute the "parent" type faster than substring manipulation.
local typename_of = {} -- For example, "ast.Exp.Name" => "ast.Exp"
local consname_of = {} -- For example, "ast.Exp.Name" => "Name"

local function is_valid_name_component(s)
    -- In particular this does not allow ".", which is our separator
    return string.match(s, "[A-Za-z_][A-Za-z_0-9]*")
end

local function make_tag(mod_name, type_name, cons_name)
    assert(is_valid_name_component(mod_name))
    assert(is_valid_name_component(type_name))
    assert(is_valid_name_component(cons_name))
    local typ = mod_name .. "." .. type_name
    local tag = typ      .. "." .. cons_name
    if typename_of[tag] then
        error(string.format("tag name %q is already being used", tag))
    end
    typename_of[tag] = typ
    consname_of[tag] = cons_name
    return tag
end

-- Create a tagged union constructor
-- @param module       Module table where the type is being defined
-- @param mod_name     Name of the module
-- @param type_name    Name of the type
-- @param constructors Name of the constructor => fields of the record
local function define_union(mod_table, mod_name, type_name, constructors)
    mod_table[type_name] = {}
    for cons_name, fields in pairs(constructors) do
        local tag = make_tag(mod_name, type_name, cons_name)
        local function cons(...)
            local args = table.pack(...)
            if args.n ~= #fields then
                error(string.format(
                    "wrong number of arguments for %s. Expected %d but received %d.",
                    cons_name, #fields, args.n))
            end
            local node = { _tag = tag }
            for i, field in ipairs(fields) do
                node[field] = args[i]
            end
            return node
        end
        mod_table[type_name][cons_name] = cons
    end
end

function tagged_union.in_namespace(mod_table, mod_name)
    assert(type(mod_table) == "table")
    assert(type(mod_name) == "string")
    return function(type_name, constructors)
        return define_union(mod_table, mod_name, type_name, constructors)
    end
end

function tagged_union.typename(tag)
    return typename_of[tag]
end

function tagged_union.consname(tag)
    return consname_of[tag]
end

-- Use this in the last "else" of a tagged union switch-case.
function tagged_union.error(tag, message)
    message = message or "input has the wrong type or an elseif case is missing"
    error(string.format("unhandled case '%s': %s", tag, message))
end

return tagged_union
