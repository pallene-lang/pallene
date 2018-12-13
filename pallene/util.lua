local util = {}

function util.abort(msg)
    io.stderr:write(msg, "\n")
    os.exit(1)
end

-- Barebones string-based template function for generating C/Lua code. Replaces
-- $VAR and ${VAR} placeholders in the `code` template by the corresponding
-- strings in the `substs` table.
function util.render(code, substs)
    local err
    local out = string.gsub(code, "%$({?)([A-Za-z_][A-Za-z_0-9]*)(}?)", function(a, k, b)
        if a == "{" and b == "" then
            err = "unmatched ${ in template"
            return ""
        end
        local v = substs[k]
        if not v then
            err = "missing template variable " .. k
            return ""
        elseif type(v) ~= "string" and type(v) ~= "number" then
            err = "template variable is not a string/number " .. k
            return ""
        end
        if a == "" and b == "}" then
            v = v .. b
        end
        return v
    end)
    if err then
        error(err)
    end
    return out
end

--
-- Shell and filesystem stuff
--

function util.split_ext(filename)
    local name, ext = string.match(filename, "(.*)%.(.*)")
    return name, ext
end

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

-- Quotes a command-line argument according to POSIX shell syntax.
function util.shell_quote(str)
    return "'" .. str:gsub("'", "'\\''") .. "'"
end

function util.shell(cmd)
    local p = io.popen(cmd)
    local out = p:read("*a")
    local ok, _ = p:close()
    if not ok then
        return false, "command failed: " .. cmd
    end
    return out
end

return util
