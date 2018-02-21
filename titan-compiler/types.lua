local typedecl = require 'titan-compiler.typedecl'

local types = typedecl(_, "Type", {
    Types = {
        Invalid     = {},
        Nil         = {},
        Boolean     = {},
        Integer     = {},
        Float       = {},
        String      = {},
        Value       = {},
        Function    = {"params", "rettypes"},
        Array       = {"elem"},
        InitList    = {"elems"},
        Record      = {"name", "fields"},
        Type        = {"type"},
    }
})

function types.is_basic(t)
    local tag = t._tag
    return tag == "TypeNil" or
           tag == "TypeBoolean" or
           tag == "TypeInteger" or
           tag == "TypeFloat" or
           tag == "TypeString" or
           tag == "TypeValue"
end

function types.is_gc(t)
    local tag = t._tag
    return tag == "TypeString" or
           tag == "TypeValue" or
           tag == "TypeArray"
end

-- XXX this should be inside typedecl call
-- constructors shouldn't do more than initalize members
function types.Module(modname, members)
    return { _tag = "Module", name = modname,
        prefix = modname:gsub("[%-.]", "_") .. "_",
        file = modname:gsub("[.]", "/") .. ".so",
        members = members }
end

function types.coerceable(source, target)
    return (types.equals(source, types.Integer()) and
            types.equals(target, types.Float())) or
           (types.equals(source, types.Float()) and
            types.equals(target, types.Integer())) or
           (types.equals(target, types.Boolean()) and
            not types.equals(source, types.Boolean())) or
           (types.equals(target, types.Value()) and
            not types.equals(source, types.Value())) or
           (types.equals(source, types.Value()) and
            not types.equals(target, types.Value()))
end

-- The type consistency relation, a-la gradual typing
function types.compatible(t1, t2)
    if types.equals(t1, t2) then
        return true
    elseif t1._tag == "TypeValue" or t2._tag == "TypeValue" then
        return true
    elseif t1._tag == "TypeArray" and t2._tag == "TypeArray" then
        return types.compatible(t1.elem, t2.elem)
    elseif t1._tag == "TypeFunction" and t2._tag == "TypeFunction" then
        if #t1.params ~= #t2.params then
            return false
        end

        for i = 1, #t1.params do
            if not types.compatible(t1.params[i], t2.params[i]) then
                return false
            end
        end

        if #t1.rettypes ~= #t2.rettypes then
            return false
        end

        for i = 1, #t1.rettypes do
            if not types.compatible(t1.rettypes[i], t2.rettypes[i]) then
                return false
            end
        end

        return true
    else
        return false
    end
end

function types.equals(t1, t2)
    local tag1, tag2 = t1._tag, t2._tag
    if tag1 == "TypeArray" and tag2 == "TypeArray" then
        return types.equals(t1.elem, t2.elem)
    elseif tag1 == "TypeFunction" and tag2 == "TypeFunction" then
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
    if     tag == "TypeInteger"     then return "integer"
    elseif tag == "TypeBoolean"     then return "boolean"
    elseif tag == "TypeString"      then return "string"
    elseif tag == "TypeNil"         then return "nil"
    elseif tag == "TypeFloat"       then return "float"
    elseif tag == "TypeValue"       then return "value"
    elseif tag == "TypeInvalid"     then return "invalid type"
    elseif tag == "TypeFunction" then
        return "function" -- TODO implement
    elseif tag == "TypeArray" then
        return "{ " .. types.tostring(t.elem) .. " }"
    elseif tag == "TypeInitList" then
        return "initlist" -- TODO implement
    elseif tag == "TypeRecord" then
        return t.name
    elseif tag == "TypeType" then
        return "type" -- TODO remove
    else
        print(tag)
        error("impossible")
    end
end

-- Builds a type for the module from the types of its public members
--   ast: AST for the module
--   returns "Module" type
function types.makemoduletype(modname, ast)
    local members = {}
    for _, tlnode in ipairs(ast) do
        if tlnode._tag ~= "AstTopLevelImport" and not tlnode.islocal and not tlnode._ignore then
            local tag = tlnode._tag
            if tag == "AstTopLevelFunc" then
                members[tlnode.name] = tlnode._type
            elseif tag == "AstTopLevelVar" then
                members[tlnode.decl.name] = tlnode._type
            end
        end
    end
    return types.Module(modname, members)
end

function types.serialize(t)
    local tag = t._tag
    if tag == "TypeArray" then
        return "Array(" ..types.serialize(t.elem) .. ")"
    elseif tag == "Module" then
        local members = {}
        for name, member in pairs(t.members) do
            table.insert(members, name .. " = " .. types.serialize(member))
        end
        return "Module(" ..
            "'" .. t.name .. "'" .. "," ..
            "{" .. table.concat(members, ",") .. "}" ..
            ")"
    elseif tag == "TypeFunction" then
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
        return tag
    end
end

return types
