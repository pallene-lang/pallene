local ast = require 'titan-compiler.ast'
local typedecl = require 'titan-compiler.typedecl'

local types = {}

local function declare_type(typename, cons)
    typedecl.declare(types, "types", typename, cons)
end

declare_type("T", {
    Invalid  = {},
    Nil      = {},
    Boolean  = {},
    Integer  = {},
    Float    = {},
    String   = {},
    Function = {"params", "rettypes"},
    Array    = {"elem"},
    Initlist = {"elems"},
    Record   = {"name", "fields"},
    Type     = {"type"},
})

function types.is_basic(t)
    local tag = t._tag
    return tag == types.T.Nil or
           tag == types.T.Boolean or
           tag == types.T.Integer or
           tag == types.T.Float or
           tag == types.T.String
end

function types.is_gc(t)
    local tag = t._tag
    return tag == types.T.String or
           tag == types.T.Function or
           tag == types.T.Array or
           tag == types.T.Record
end

-- XXX this should be inside typedecl call
-- constructors shouldn't do more than initalize members
-- XXX this should not be a type. This makes it possible to
-- construct nonsense things like a function type that returns
-- a module type
function types.T.Module(modname, members)
    return { _tag = types.T.Module, name = modname,
        prefix = modname:gsub("[%-.]", "_") .. "_",
        file = modname:gsub("[.]", "/") .. ".so",
        members = members }
end

function types.coerceable(source, target)
    return
        (source._tag == types.T.Integer and target._tag == types.T.Float) or
        (source._tag == types.T.Float   and target._tag == types.T.Integer) or
        (source._tag ~= types.T.Boolean and target._tag == types.T.Boolean)
end

function types.equals(t1, t2)
    local tag1, tag2 = t1._tag, t2._tag
    if tag1 == types.T.Array and tag2 == types.T.Array then
        return types.equals(t1.elem, t2.elem)
    elseif tag1 == types.T.Function and tag2 == types.T.Function then
        if #t1.params ~= #t2.params then
            return false
        end

        for i = 1, #t1.params do
            if not types.equals(t1.params[i], t2.params[i]) then
                return false
            end
        end

        if #t1.rettypes ~= #t2.rettypes then
            return false
        end

        for i = 1, #t1.rettypes do
            if not types.equals(t1.rettypes[i], t2.rettypes[i]) then
                return false
            end
        end

        return true
    elseif tag1 == tag2 then
        return true
    else
        return false
    end
end

function types.tostring(t)
    local tag = t._tag
    if     tag == types.T.Integer     then return "integer"
    elseif tag == types.T.Boolean     then return "boolean"
    elseif tag == types.T.String      then return "string"
    elseif tag == types.T.Nil         then return "nil"
    elseif tag == types.T.Float       then return "float"
    elseif tag == types.T.Invalid     then return "invalid type"
    elseif tag == types.T.Function then
        return "function" -- TODO implement
    elseif tag == types.T.Array then
        return "{ " .. types.tostring(t.elem) .. " }"
    elseif tag == types.T.Initlist then
        return "initlist" -- TODO implement
    elseif tag == types.T.Record then
        return t.name
    elseif tag == types.T.Type then
        return "type" -- TODO remove
    else
        error("impossible")
    end
end

-- Builds a type for the module from the types of its public members
--   prog: AST for the module
--   returns types.T.Module type
function types.makemoduletype(modname, prog)
    local members = {}
    for _, tlnode in ipairs(prog) do
        if tlnode._tag ~= ast.Toplevel.Import and not tlnode.islocal and not tlnode._ignore then
            local tag = tlnode._tag
            if tag == ast.Toplevel.Func then
                members[tlnode.name] = tlnode._type
            elseif tag == ast.Toplevel.Var then
                members[tlnode.decl.name] = tlnode._type
            end
        end
    end
    return types.T.Module(modname, members)
end

function types.serialize(t)
    local tag = t._tag
    if tag == types.T.Array then
        return "Array(" ..types.serialize(t.elem) .. ")"
    elseif tag == types.T.Module then
        local members = {}
        for name, member in pairs(t.members) do
            table.insert(members, name .. " = " .. types.serialize(member))
        end
        return "Module(" ..
            "'" .. t.name .. "'" .. "," ..
            "{" .. table.concat(members, ",") .. "}" ..
            ")"
    elseif tag == types.T.Function then
        local ptypes = {}
        for _, pt in ipairs(t.params) do
            table.insert(ptypes, types.serialize(pt))
        end
        local rettypes = {}
        for _, rt in ipairs(t.rettypes) do
            table.insert(rettypes, types.serialize(rt))
        end
        return "Function(" ..
            "{" .. table.concat(ptypes, ",") .. "}" .. "," ..
            "{" .. table.concat(rettypes, ",") .. "}" ..
            ")"
    else
        return types.tostring(t)
    end
end

return types
