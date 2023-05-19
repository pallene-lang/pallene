-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- TAGGED UNIONS
-- =============
-- Pallene's compiler uses many tagged unions / variant records. We represent
-- them as tables with a string `_tag`. This module exports helper functions for
-- custructing such tagged unions.
--
-- For example, the following block of code in the `ast` module creates
-- three constructor functions called `ast.Var.Name`, `ast.Var.Bracket`, and
-- `ast.Var.Dot`.
--
--     declare_type("Var", {
--         Name    = {"loc", "name"},
--         Bracket = {"loc", "t", "k"},
--         Dot     = {"loc", "exp", "name"}
--     })
--
-- And we can call them like this
--
--     node = ast.Var.Name(loc, name)
--
-- and it produces a table like this:
--
--     {
--         _tag = "ast.Var.Name",
--         loc = loc,
--         name = name,
--     }

local tagged_union = {}

-- Ensure type tags are unique
-- And keep track of who is the "parent" type
local typename_of = {} -- For example, "ast.Exp.Name" => "ast.Exp"
local consname_of = {} -- For example, "ast.Exp.Name" => "

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
    else
        typename_of[tag] = typ
        consname_of[tag] = cons_name
        return tag
    end
end

-- Create a namespaced algebraic datatype.
-- These objects can be pattern matched by their _tag.
-- See `ast.lua` and `types.lua` for usage examples.
--
-- @param module       Module table where the type is being defined
-- @param mod_name     Name of the type's module (only used by tostring)
-- @param type_name    Name of the type
-- @param constructors Table describing the constructors of the ADT.
function tagged_union.declare(module, mod_name, type_name, constructors)
    module[type_name] = {}
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
        module[type_name][cons_name] = cons
    end
end

function tagged_union.typename(tag)
    return typename_of[tag]
end

function tagged_union.consname(tag)
    return consname_of[tag]
end

-- Throw an error at the given tag.
--
-- @param tag     The type tag (or token string) at which the error is to be thown (string)
-- @param message The optional error message. (?string)
function tagged_union.tag_error(tag, message)
    message = message or "input has the wrong type or an elseif case is missing"
    error(string.format("unhandled case '%s': %s", tag, message))
end

return tagged_union
