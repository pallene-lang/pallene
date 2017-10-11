
local types = {}

function types.Function(ptypes, rettype)
    return { _tag = "Function", params = ptypes, ret = rettype }
end

function types.Array(etype)
    return { _tag = "Array", elem = etype }
end

local base_types = { "Integer", "Boolean", "String", "Nil", "Float" }

for _, t in ipairs(base_types) do
    types[t] = { _tag = t }
    base_types[t] = types[t]
end

function types.Base(name)
    return base_types[name]
end

function types.has_tag(t, name)
    return t._tag == name
end

function types.equals(t1, t2)
    local tag1, tag2 = t1._tag, t2._tag
    if tag1 == "Array" and tag2 == "Array" then
        return types.equals(t1.elem, t2.elem)
    elseif tag1 == "Function" and tag2 == "Function" then
        if types.equals(t1.ret, t2.ret) and (#t1.params == #t2.params) then
            for i = 1, #t1.params do
                if not types.equals(t1.params[i], t2.params[i]) then
                    return false
                end
            end
            return true
        end
    else
        return tag1 == tag2
    end
    return false
end

function types.tostring(t)
    local tag = t._tag
    if tag == "Array" then
        return "{ " .. types.tostring(t.elem) .. " }"
    elseif tag == "Function" then
    else
        return string.lower(tag)
    end
end

return types