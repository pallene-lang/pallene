-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- C CODE GENERATION
-- =================
-- This module contains some helper functions for generating C code.
-- To keep the output readable and debuggable, at the end we re-indent the
-- program, based on the braces and curly braces. We find that this method
-- is simpler than trying to generate indented things right out of the gate.

local re = require "re"

local C = {}

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
    return string.format("%d", n)
end

function C.boolean(b)
    return (b and "1" or "0")
end

function C.float(n)
    -- To keep things pretty, we try to find the shortest representation that still round trips.
    -- For normal floats, the only way in standard C or Lua is to try every possible precision,
    -- which is slow but works. For infinities, the HUGE_VAL macro is part of math.h.
    -- NaNs are disallowed, because they cannot be represented as a C literal.
    if n ~= n then
        error("NaN cannot be round-tripped")
    elseif n == math.huge then
        return "HUGE_VAL"
    elseif n == -math.huge then
        return "-HUGE_VAL"
    else
        -- We start at 6 to avoid exponent notation for small numbers, e.g. 10.0 -> 1e+01
        -- We don't go straight to 17 because it might be ugly, e.g. 3.14 -> 3.1400000000000001
        -- Be careful with floating point numbers that are also integers.
        for p = 6, 17 do
            local s = string.format("%."..p.."g", n)
            if s:match("^%-?[0-9]+$") then
                s = s .. ".0"
            end
            if tonumber(s) == n then
                return s
            end
         end
         -- 17 digits should have been enough to round trip any non-NaN, non-infinite double.
         -- See https://stackoverflow.com/a/21162120 and DBL_DECIMAL_DIG in float.h
         error("impossible")
    end
end

function C.comment(str)
    str = str:gsub("\n", " ")  -- (our reformatter expects single-line comments)
    str = str:gsub("%*%/", "")
    return string.format("/* %s */", str)
end

--
-- Local variable, function argument and struct member declarations
--

function C.declaration(ctyp, name)
    -- Put the *'s next to the name to make the pointers look nice.
    local non_ptr, ptr = string.match(ctyp, '^(.-)([%s%*]*)$')
    if ptr ~= "" then ptr = ptr:gsub("%s", "") end
    return string.format("%s %s%s", non_ptr, ptr, name)
end

--
-- Pretty printing
--

local unquoted = re.compile([[
    line <- {| item* |}
    item <- long_comment / line_comment / char_lit / string_lit / brace / .

    long_comment <- "/*" finish_long
    finish_long  <- "*/" / . finish_long

    line_comment <- "//" .*

    char_lit  <- "'" escaped "'"
    escaped <- '\'. / .

    string_lit    <- '"' finish_string
    finish_string <- '"' / escaped finish_string

    brace <- { [{}()] }
]])

local function count_braces(line)
    local n = 0
    for _, c in ipairs(unquoted:match(line)) do
        if c == "{" or c == "(" then n = n + 1 end
        if c == "}" or c == ")" then n = n - 1 end
    end
    return n
end

-- This function reformats a string corresponding to a C source file. It allows us to produce
-- readable C output without having to worry about indentation while we are generating it.
--
-- The algorithm is not very clever, so you must follow some rules if you want to get good-looking
-- results:
--
--   * Use braces on if statements, while loops, and for loops.
--   * /**/-style comments must not span multiple lines
--   * goto labels must appear on a line by themselves
--
function C.reformat(input)
    local out = {}
    local depth = 0
    local previous_line = nil
    for line in input:gmatch("([^\n]*)") do
        line = line:match("^%s*(.-)%s*$")

        -- We ignore blank lines in the input because most of them are garbage produced by the code
        -- generator. However, sometimes we want to intentionally leave a blank line for formatting
        -- purposes. To do that, use a line that is just an empty C comment: /**/
        if line == "" then
            goto continue
        end
        if line == "/**/" then
            line = ""
        end
        if line == "" and previous_line == "" then
            goto continue
        end

        local nspaces
        if line:match("^#") then
            -- Preprocessor directives are never indented
            nspaces = 0

        elseif line:match("^[A-Za-z_][A-Za-z_0-9]*:$") then
            -- Labels are indented halfway
            nspaces = math.max(0, 4*depth - 2)

        else
            -- Regular lines are indented based on {} and ().
            local unindent_this_line = string.match(line, "^[})]")
            nspaces = 4 * (depth - (unindent_this_line and 1 or 0))
            depth = depth + count_braces(line)
            assert(depth >= 0, "Unbalanced indentation. Too many '}'s")
        end

        table.insert(out, string.rep(" ", nspaces))
        table.insert(out, line)
        table.insert(out, "\n")

        previous_line = line

        ::continue::
    end
    assert(depth == 0, "Unbalanced indentation at end of file.")
    return table.concat(out)
end

return C
