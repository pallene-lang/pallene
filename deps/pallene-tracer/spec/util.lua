-- Copyright (c) 2024, The Pallene Developers
-- Pallene Tracer is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = {}

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

return util
