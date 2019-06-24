local typedecl = require "pallene.typedecl"

local types = {}

local function declare_type(type_name, cons)
    typedecl.declare(types, "types", type_name, cons)
end

declare_type("T", {
    Value    = {},
    Void     = {}, -- For functions with 0 returns
    Nil      = {},
    Boolean  = {},
    Integer  = {},
    Float    = {},
    String   = {},
    Function = {"params", "ret_types"},
    Array    = {"elem"},
    Record   = {
        "name",        -- for tostring only
        "field_names", -- same order as the source type declaration
        "field_types", -- map { string => types.T }
    },
})

function types.is_gc(t)
    local tag = t._tag
    if     tag == "types.T.Void" or
           tag == "types.T.Nil" or
           tag == "types.T.Boolean" or
           tag == "types.T.Integer" or
           tag == "types.T.Float"
    then
        return false

    elseif tag == "types.T.Value" or
           tag == "types.T.String" or
           tag == "types.T.Function" or
           tag == "types.T.Array" or
           tag == "types.T.Record"
    then
        return true

    else
        error("impossible")
    end
end

-- This helper function implements both the type equality relation and the and
-- the gradual type consistency relation from gradual typing.
-- Gradual type consistency is a relaxed form of equality where the the "value"
-- type is considered to be consistent with all other types.
local function equivalent(t1, t2, is_gradual)
    assert(is_gradual ~= nil)
    local tag1 = t1._tag
    local tag2 = t2._tag

    if is_gradual and (tag1 == "types.T.Value" or tag2 == "types.T.Value") then
        return true

    elseif tag1 ~= tag2 then
        return false

    elseif tag1 == "types.T.Value" or
           tag1 == "types.T.Void" or
           tag1 == "types.T.Nil" or
           tag1 == "types.T.Boolean" or
           tag1 == "types.T.Integer" or
           tag1 == "types.T.Float" or
           tag1 == "types.T.String"
    then
        return true

    elseif tag1 == "types.T.Array" then
        return equivalent(t1.elem, t2.elem, is_gradual)

    elseif tag1 == "types.T.Function" then
        if #t1.params ~= #t2.params then
            return false
        end

        for i = 1, #t1.params do
            if not equivalent(t1.params[i], t2.params[i], is_gradual) then
                return false
            end
        end

        if #t1.ret_types ~= #t2.ret_types then
            return false
        end

        for i = 1, #t1.ret_types do
            if not equivalent(t1.ret_types[i], t2.ret_types[i], is_gradual) then
                return false
            end
        end

        return true

    elseif tag1 == "types.T.Record" then
        -- Record types are nominal
        return t1 == t2

    else
        return error("impossible")
    end
end

function types.equals(t1, t2)
    return equivalent(t1, t2, false)
end

function types.consistent(t1, t2)
    return equivalent(t1, t2, true)
end

function types.tostring(t)
    local tag = t._tag
    if     tag == "types.T.Value"       then return "value"
    elseif tag == "types.T.Void"        then return "void"
    elseif tag == "types.T.Nil"         then return "nil"
    elseif tag == "types.T.Boolean"     then return "boolean"
    elseif tag == "types.T.Integer"     then return "integer"
    elseif tag == "types.T.Float"       then return "float"
    elseif tag == "types.T.String"      then return "string"
    elseif tag == "types.T.Function" then
        return "function" -- TODO implement
    elseif tag == "types.T.Array" then
        return "{ " .. types.tostring(t.elem) .. " }"
    elseif tag == "types.T.Record" then
        return t.name
    else
        error("impossible")
    end
end

return types
