local typedecl = require "pallene.typedecl"

local types = {}

local function declare_type(typename, cons)
    typedecl.declare(types, "types", typename, cons)
end

declare_type("T", {
    Void     = {}, -- For functions with 0 returns
    Nil      = {},
    Boolean  = {},
    Integer  = {},
    Float    = {},
    String   = {},
    Function = {"params", "rettypes"},
    Array    = {"elem"},
    LRecord  = {"fields"},
    Record   = {"type_decl"},
    Builtin  = {"builtin_decl"},
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
           tag == types.T.LRecord or
           tag == types.T.Record
end

-- Can [source] be coerced to [target] via a cast?
-- Note: this function only is cares about whether a cast is possible. It is
-- not concerned with automatic coercion insertion.
function types.coerceable(source, target)
    return
        types.equals(source, target) or
        (source._tag == types.T.Integer and target._tag == types.T.Float) or
        (source._tag == types.T.Float   and target._tag == types.T.Integer)
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
    elseif tag1 == types.T.LRecord and tag2 == types.T.LRecord then
        local f1 = t1.fields
        local f2 = t2.fields
        for name in pairs(f1) do
            if not f2[name] or not types.equals(f1[name], f2[name]) then
                return false
            end
        end

        for name in pairs(f2) do
            if not f1[name] or not types.equals(f1[name], f2[name]) then
                return false
            end
        end

        return true
    else
        return tag1 == tag2
    end
end

function types.tostring(t)
    local tag = t._tag
    if     tag == types.T.Integer     then return "integer"
    elseif tag == types.T.Boolean     then return "boolean"
    elseif tag == types.T.String      then return "string"
    elseif tag == types.T.Nil         then return "nil"
    elseif tag == types.T.Float       then return "float"
    elseif tag == types.T.Void        then return "void"
    elseif tag == types.T.Function then
        return "function" -- TODO implement
    elseif tag == types.T.Array then
        return "{ " .. types.tostring(t.elem) .. " }"
    elseif tag == types.T.LRecord then
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
    elseif tag == types.T.Record then
        return t.type_decl.name
    elseif tag == types.T.Builtin then
        return "builtin(".. t.builtin_decl.name ..")"
    else
        error("impossible")
    end
end

return types
