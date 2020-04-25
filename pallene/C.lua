-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local C = {}
--
-- This module contains some helper functions for generating C code.
--

--
-- Conversions from Lua values to C literals
--

local some_c_escape_sequences = {
    -- Strictly speaking, we only need to escape quotes and backslashes.
    -- However, escaping some extra characters helps readability.
    ["\\"] = "\\\\",
    ["\""] = "\\\"",
    ["\a"] = "\\a",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
    ["\v"] = "\\v",
}

function C.string(s)
    return '"' .. (s:gsub('.', some_c_escape_sequences)) .. '"'
end

function C.integer(n)
    return string.format("%i", n)
end

function C.boolean(b)
    return (b and "1" or "0")
end

function C.float(n)
    -- 17 decimal digits should be able to accurately represent any IEE-754
    -- double-precision floating point number except for NaN and infinities.
    -- The HUGE_VAL macro is a part of math.h. For more info, please see the
    -- quotefloat function in lstrlib.c, tostringbuff in lobject.c, and
    -- https://stackoverflow.com/a/21162120
    if n ~= n then
        error("NaN cannot be round-tripped")
    elseif n == math.huge then
        return "HUGE_VAL"
    elseif n == -math.huge then
        return "-HUGE_VAL"
    else
        local s = string.format("%.17g", n)
        if s:match("^%-?[0-9]+$") then
            -- Looks like an integer. Add a decimal point to force to be double.
            s = s .. ".0"
        end
        return s
    end
end

--
-- Comments
-- (The reformater assumes that they are single-line)

function C.comment(str)
    str = str:gsub("\n", " ")
    str = str:gsub("%*%/", "")
    return string.format("/* %s */", str)
end

--
-- Pretty printing
--

-- This function reformats a string corresponding to a C source file. It allows
-- us to produce readable C output without having to worry about indentation
-- while we are generating it.
--
-- The algorithm is not very clever, so you must follow some rules if you want
-- to get good-looking results:
--
--   * Use braces on if statements, while loops, and for loops.
--   * /**/-style comments must not span multiple lines
--   * Be careful about special characters inside strings and comments
--   * goto labels must appear on a line by themselves
--   * Use spaces for indentation instead of tabs
--
function C.reformat(input)
    local out = {}
    local depth = 0
    local previous_is_blank = true
    for line in input:gmatch("([^\n]*)") do
        line = line:match("^ *(.-) *$")

        -- We use tab characters to mark blank lines that should be preserved in
        -- the output. (This trick allows reformat to be idempotent). However,
        -- typing a \t inside [[ ]] strings is hard so we also use /**/ as a
        -- blank line marker.
        if line == "/**/" then
            line = "\t"
        end

        -- Clusters of blank lines are merged into a single blank line.
        local is_blank          = not not line:match("^\t*$")
        local intentional_blank = not not line:match("^\t+$")
        if is_blank and (
            previous_is_blank or
            (depth > 0 and not intentional_blank))
        then
            goto continue
        end

        local nspaces
        if line:match("^#") then
            -- Preprocessor directives are never indented
            nspaces = 0

        elseif line:match("^[A-Za-z_][A-Za-z_0-9]*:$") then
            -- Labels are indented halfway
            nspaces = math.max(0, 4 * depth - 2)

        else
            -- Otherwise, count braces and parens
            local without_strings = line:gsub([[\"]], ""):gsub('".-"', "")
            local without_comments = without_strings:gsub("/%*.-%*/", "")
                                                    :gsub("//.*", "")
            local _, n_open  = string.gsub(without_comments, "[{(]", "%1")
            local _, n_close = string.gsub(without_comments, "[})]", "%1")
            local unindent_this_line = string.match(line, "^[})]")

            nspaces = 4 * (depth - (unindent_this_line and 1 or 0))

            if     n_open > n_close then
                depth = depth + 1
            elseif n_open < n_close then
                depth = depth - 1
            end

            assert(depth >= 0, "Unbalanced indentation. Too many '}'s")
        end

        table.insert(out, string.rep(" ", nspaces))
        table.insert(out, line)
        table.insert(out, "\n")

        previous_is_blank = is_blank

        ::continue::
    end
    assert(depth == 0, "Unbalanced indentation at end of file.")
    return table.concat(out)
end

return C
