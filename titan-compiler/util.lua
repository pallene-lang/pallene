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

-- Barebones string-based template function for generating C/Lua code. Replaces
-- $VAR and ${VAR} placeholders in the `code` template by the corresponding
-- strings in the `substs` table.
function util.render(code, substs)
    return (string.gsub(code, "%$({?)([A-Za-z_][A-Za-z_0-9]*)(}?)", function(a, k, b)
        if a == "{" and b == "" then
            error("unmatched ${ in template")
        end
        local v = substs[k]
        if not v then
            error("Internal compiler error: missing template variable " .. k)
        end
        if a == "" and b == "}" then
            v = v .. b
        end
        return v
    end))
end

function util.shell(cmd)
    local p = io.popen(cmd)
    out = p:read("*a")
    p:close()
    return out
end

function util.split_ext(file_name)
	local name, ext = string.match(file_name, "(.*)%.(.*)")
    return name, ext
end

return util
