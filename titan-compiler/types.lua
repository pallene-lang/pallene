local ast = require 'titan-compiler.ast'
local typedecl = require 'titan-compiler.typedecl'

local types = typedecl.decl{
    Types = {
        Invalid     = {},
        Nil         = {},
        Boolean     = {},
        Integer     = {},
        Float       = {},
        String      = {},
        Function    = {"params", "rettypes"},
        Array       = {"elem"},
        InitList    = {"elems"},
        Record      = {"name", "fields"},
        Type        = {"type"},
    }
}

function types.is_basic(t)
    local tag = t._tag
    return tag == types.Nil or
           tag == types.Boolean or
           tag == types.Integer or
           tag == types.Float or
           tag == types.String
end

function types.is_gc(t)
    local tag = t._tag
    return tag == types.String or
           tag == types.Function or
           tag == types.Array or
           tag == types.Record
end

-- XXX this should be inside typedecl call
-- constructors shouldn't do more than initalize members
-- XXX this should not be a type. This makes it possible to
-- construct nonsense things like a function type that returns
-- a module type
function types.Module(modname, members)
    return { _tag = types.Module, name = modname,
        prefix = modname:gsub("[%-.]", "_") .. "_",
        file = modname:gsub("[.]", "/") .. ".so",
        members = members }
end

function types.coerceable(source, target)
    return
        (source._tag == types.Integer and target._tag == types.Float) or
        (source._tag == types.Float   and target._tag == types.Integer) or
        (source._tag ~= types.Boolean and target._tag == types.Boolean)
end

function types.equals(t1, t2)
    local tag1, tag2 = t1._tag, t2._tag
    if tag1 == types.Array and tag2 == types.Array then
        return types.equals(t1.elem, t2.elem)
    elseif tag1 == types.Function and tag2 == types.Function then
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
    if     tag == types.Integer     then return "integer"
    elseif tag == types.Boolean     then return "boolean"
    elseif tag == types.String      then return "string"
    elseif tag == types.Nil         then return "nil"
    elseif tag == types.Float       then return "float"
    elseif tag == types.Invalid     then return "invalid type"
    elseif tag == types.Function then
        return "function" -- TODO implement
    elseif tag == types.Array then
        return "{ " .. types.tostring(t.elem) .. " }"
    elseif tag == types.InitList then
        return "initlist" -- TODO implement
    elseif tag == types.Record then
        return t.name
    elseif tag == types.Type then
        return "type" -- TODO remove
    else
        error("impossible")
    end
end

-- Builds a type for the module from the types of its public members
--   prog: AST for the module
--   returns types.Module type
function types.makemoduletype(modname, prog)
    local members = {}
    for _, tlnode in ipairs(prog) do
        if tlnode._tag ~= ast.TopLevelImport and not tlnode.islocal and not tlnode._ignore then
            local tag = tlnode._tag
            if tag == ast.TopLevelFunc then
                members[tlnode.name] = tlnode._type
            elseif tag == ast.TopLevelVar then
                members[tlnode.decl.name] = tlnode._type
            end
        end
    end
    return types.Module(modname, members)
end

function types.serialize(t)
    local tag = t._tag
    if tag == types.Array then
        return "Array(" ..types.serialize(t.elem) .. ")"
    elseif tag == types.Module then
        local members = {}
        for name, member in pairs(t.members) do
            table.insert(members, name .. " = " .. types.serialize(member))
        end
        return "Module(" ..
            "'" .. t.name .. "'" .. "," ..
            "{" .. table.concat(members, ",") .. "}" ..
            ")"
    elseif tag == types.Function then
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
