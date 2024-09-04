-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local types = {}

local tagged_union = require "pallene.tagged_union"
local define_union = tagged_union.in_namespace(types, "types")

define_union("T", {
    Any      = {},
    Nil      = {},
    Boolean  = {},
    Integer  = {},
    Float    = {},
    String   = {},
    Function = {"arg_types", "ret_types"},
    Array    = {"elem"},
    Table    = {"fields"},
    Record   = {
        "name",          -- for tostring only
        "field_names",   -- same order as the source type declaration
        "field_types",   -- map { string => types.T }
        "is_upvalue_box" -- whether this is an artificial upvalue record
                         --  (check assignment_conversion.lua)
    },
})

function types.is_gc(t)
    local tag = t._tag
    if     tag == "types.T.Nil" or
           tag == "types.T.Boolean" or
           tag == "types.T.Integer" or
           tag == "types.T.Float"
    then
        return false

    elseif tag == "types.T.Any" or
           tag == "types.T.String" or
           tag == "types.T.Function" or
           tag == "types.T.Array" or
           tag == "types.T.Table" or
           tag == "types.T.Record"
    then
        return true

    else
        tagged_union.error(tag)
    end
end

function types.is_condition(t)
    local tag = t._tag
    if     tag == "types.T.Any" or
           tag == "types.T.Boolean"
    then
        return true

    elseif tag == "types.T.Nil" or
           tag == "types.T.Integer" or
           tag == "types.T.Float" or
           tag == "types.T.String" or
           tag == "types.T.Function" or
           tag == "types.T.Array" or
           tag == "types.T.Table" or
           tag == "types.T.Record"
    then
        return false

    else
        tagged_union.error(tag)
    end

end

function types.is_indexable(t)
    local tag = t._tag
    if     tag == "types.T.Table" or
           tag == "types.T.Record"
    then
        return true

    elseif tag == "types.T.Nil" or
           tag == "types.T.Boolean" or
           tag == "types.T.Integer" or
           tag == "types.T.Float" or
           tag == "types.T.Any" or
           tag == "types.T.String" or
           tag == "types.T.Function" or
           tag == "types.T.Array"
    then
        return false

    else
        tagged_union.error(tag)
    end
end

function types.indices(t)
    local tag = t._tag
    if     tag == "types.T.Table" then
        return t.fields

    elseif tag == "types.T.Record" then
        return t.field_types

    elseif tagged_union.typename(tag) == "types.T" then
        -- Not indexable
        assert(false)

    else
        tagged_union.error(tag)
    end
end

function types.equals(t1, t2)
    local tag1 = t1._tag
    local tag2 = t2._tag

    assert(tagged_union.typename(tag1) == "types.T")
    assert(tagged_union.typename(tag2) == "types.T")

    if tag1 ~= tag2 then
        return false

    elseif tag1 == "types.T.Any" or
           tag1 == "types.T.Nil" or
           tag1 == "types.T.Boolean" or
           tag1 == "types.T.Integer" or
           tag1 == "types.T.Float" or
           tag1 == "types.T.String"
    then
        return true

    elseif tag1 == "types.T.Array" then
        return types.equals(t1.elem, t2.elem)

    elseif tag1 == "types.T.Table" then
        local f1 = t1.fields
        local f2 = t2.fields

        for name in pairs(f1) do
            if not f2[name] then
                return false
            end
        end

        for name in pairs(f2) do
            if not f1[name] then
                return false
            end
        end

        for name in pairs(f2) do
            if not types.equals(f1[name], f2[name]) then
                return false
            end
        end

        return true

    elseif tag1 == "types.T.Function" then
        if #t1.arg_types ~= #t2.arg_types then
            return false
        end

        for i = 1, #t1.arg_types do
            if not types.equals(t1.arg_types[i], t2.arg_types[i]) then
                return false
            end
        end

        if #t1.ret_types ~= #t2.ret_types then
            return false
        end

        for i = 1, #t1.ret_types do
            if not types.equals(t1.ret_types[i], t2.ret_types[i]) then
                return false
            end
        end

        return true

    elseif tag1 == "types.T.Record" then
        -- Record types are nominal
        return t1 == t2

    else
        return tagged_union.error(tag1,
            string.format("attempt to check equivalence of types %s and %s.", tag1, tag2))
    end
end

-- We consider types to be consistent if type casts between them are allowed.
-- We forbid type casts that are 100% guaranteed to fail, e.g. int=>string.
-- This is looser than the consistency requirement from gradual typing.
function types.consistent(t1, t2)
    return (
        t1._tag == "types.T.Any" or
        t2._tag == "types.T.Any" or
        t1._tag == t2._tag)
end

local function join_type_list(list)
    local parts = {}
    for _, item in pairs(list) do
        local part = types.tostring(item);
        table.insert(parts, part)
    end
    return "(" .. table.concat(parts, ", ") .. ")"
end

function types.tostring(t)
    local tag = t._tag
    if     tag == "types.T.Any"         then return "any"
    elseif tag == "types.T.Nil"         then return "nil"
    elseif tag == "types.T.Boolean"     then return "boolean"
    elseif tag == "types.T.Integer"     then return "integer"
    elseif tag == "types.T.Float"       then return "float"
    elseif tag == "types.T.String"      then return "string"
    elseif tag == "types.T.Function" then
        return string.format("function type %s -> %s",
            join_type_list(t.arg_types), join_type_list(t.ret_types))
    elseif tag == "types.T.Array" then
        return "{ " .. types.tostring(t.elem) .. " }"
    elseif tag == "types.T.Table" then
        local sorted_fields = {}
        for name, typ in pairs(t.fields) do
            table.insert(sorted_fields, {name = name, typ = typ})
        end
        table.sort(sorted_fields, function(a, b) return a.name < b.name end)

        local parts = {}
        for _, field in ipairs(sorted_fields) do
            local typ = types.tostring(field.typ)
            table.insert(parts, string.format("%s: %s", field.name, typ))
        end

        return "{ " .. table.concat(parts, ", ") .. " }"

    elseif tag == "types.T.Record" then
        return t.name
    else
        tagged_union.error(tag)
    end
end

local function is_optional(t)
    return t._tag == 'types.T.Any' or t._tag == "types.T.Nil"
end

-- The rightmost arguments to a function may be optional.
-- Input: list of argument types
-- Output: number of parameter that are mandatory.
function types.number_of_mandatory_args(argtypes)
    local n = #argtypes
    while 1 <= n and is_optional(argtypes[n]) do
        n = n - 1
    end
    return n
end

return types
