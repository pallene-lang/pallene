-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = {}

function util.abort(msg)
    io.stderr:write(msg, "\n")
    os.exit(1)
end

-- String templates for C and Lua code.
-- Replaces $VAR and ${VAR} placeholders in the `code` string, with values from `substs`.
--
-- Don't call this function in tail-call position; wrap the call in parens if necessary.
-- This way you can get an useful line number if there is a template error.
function util.render(code, substs)
    return (string.gsub(code,
        "%$({?)([A-Za-z_][A-Za-z_0-9]*)(}?)",
        function(open, k,close)
            local v = substs[k]

            if open == "{" and close == "" then
                error("unclosed ${ in template")
            end
            if not v then
                error("missing template variable " .. k)
            end
            if type(v) ~= "string" then
                error("template variable is not a string " .. k)
            end

            if open == "" then
                return v .. close
            else
                return v
            end
        end
    ))
end

--
-- Shell and filesystem stuff
--

function util.split_ext(file_name)
    local name, ext = string.match(file_name, "(.*)%.(.*)")
    return name, ext
end

function util.get_file_contents(file_name)
    local f, err = io.open(file_name, "r")
    if not f then
        return false, err
    end
    local s = f:read("a")
    f:close()
    if not s then
        return false, "unable to open file " .. file_name
    else
        return s
    end
end

function util.set_file_contents(file_name, contents)
    local f, err = io.open(file_name, "w")
    if not f then
        return false, err
    end
    f:write(contents)
    f:close()
    return true
end

-- Quotes a command-line argument according to POSIX shell syntax.
-- Uses a whitelist of safe chars to avoid quoting too much
function util.shell_quote(str)
    if string.match(str, "^[%w./_-]+$") then
        return str
    else
        return "'" .. string.gsub(str, "'", "'\\''") .. "'"
    end
end

function util.execute(cmd)
    local ok = os.execute(cmd)
    if ok then
        return true
    else
        return false, "command failed: " .. cmd
    end
end

function util.outputs_of_execute(cmd)
    local out_file = os.tmpname()
    local err_file = os.tmpname()

    local redirected =
        cmd ..
        " > "  .. util.shell_quote(out_file) ..
        " 2> " .. util.shell_quote(err_file)

    local ok, err = util.execute(redirected)
    local out_content = assert(util.get_file_contents(out_file))
    local err_content = assert(util.get_file_contents(err_file))
    os.remove(out_file)
    os.remove(err_file)
    return ok, err, out_content, err_content
end

--
-- OOP
--

function util.Class()
    local cls = {}
    cls.__index = cls

    cls.new = function(...)
        local self = setmetatable({}, cls)
        self:init(...)
        return self
    end

    return cls
end

function util.expand_type_aliases(ast_node, visited)
    local types = require "pallene.types"
    visited = visited or {}

    if visited[ast_node] then
        return visited[ast_node]
    end

    local this = types.expand_typealias(ast_node)

    visited[this] = this
    if this ~= ast_node then
        -- If the node was replaced by expand_typealias, then we need to
        -- make sure that we don't visit it again.
        visited[ast_node] = this
    end

    for k, v in pairs(this) do
        if type(v) == "table" then
            this[k] = util.expand_type_aliases(v, visited)
        end
    end
    
    return this
end

return util
