local util = {}

function util.get_file_contents(filename)
    local f, err = io.open(filename, "r")
    if not f then
        return false, err
    end
    local s = f:read("a")
    f:close()
    if not s then
        return false, "unable to open file " .. filename
    else
        return s
    end
end

function util.set_file_contents(filename, contents)
    local f, err = io.open(filename, "w")
    if not f then
        return false, err
    end
    f:write(contents)
    f:close()
    return true
end

-- Barebones string-based template function for generating C/Lua code.
-- Replaces $VAR placeholders in the `code` template by the corresponding
-- strings in the `substs` table.
function util.render(code, substs)
    return (string.gsub(code, "$([%w_]+)", function(k)
        local v = substs[k]
        if not v then
            error("Internal compiler error: missing template variable " .. k)
        end
        return v
    end))
end

function util.make_visitor(functions)
    return function(node, ...)
        assert(type(node) == "table")
        assert(node._tag)
        local f = assert(functions[node._tag])
        return f(node, ...)
    end
end

--
-- Functional
--

function util.curry(f, a)
    return function(...)
        return f(a, ...)
    end
end

return util
