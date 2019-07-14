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
    -- We use hexadecimal float literals (%a) to avoid losing any precision.
    -- This feature is part of the C99 and C++17 standards.
    return string.format("%a /*%f*/", n, n)
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
--
function C.reformat(input)
    local out = {}
    local depth = 0
    local previous_is_blank = true
    for line in input:gmatch("([^\n]*)") do
        line = line:match("^[ \t]*(.-)[ \t]*$")

        -- Collapse groups of empty lines into a single empty line.
        local is_blank = (#line == 0)
        if not (is_blank and previous_is_blank) then

            local nspaces
            if line:match("^#") then
                -- Preprocessor directives are never indented
                nspaces = 0

            elseif line:match("^[A-Za-z_][A-Za-z_0-9]*:$") then
                -- Labels are indented halfway
                nspaces = math.max(0, 4 * depth - 2)

            else
                -- Otherwise, count braces and parens
                local without_strings = line:gsub('\\\"', "")
                                            :gsub('".-"', "")
                local without_comments = without_strings:gsub("/%*.-%*/", "")
                                                        :gsub("//.*", "")
                local n_open  = #string.gsub(without_comments, "[^{(]", "")
                local n_close = #string.gsub(without_comments, "[^})]", "")
                local unindent_this_line = string.match(line, "^[})]")

                nspaces = 4 * (depth - (unindent_this_line and 1 or 0))

                if     n_open > n_close then
                    depth = depth + 1
                elseif n_open < n_close then
                    depth = depth - 1
                end

                if depth < 0 then
                    -- Don't let the indentation level get negative. If by any
                    -- chance our heuristics fail to spot an open brace or
                    -- paren, this confines the messed up indentation to a
                    -- single function.
                    depth = 0
                end
            end

            table.insert(out, string.rep(" ", nspaces))
            table.insert(out, line)
            table.insert(out, "\n")
        end
        previous_is_blank = is_blank
    end
    return table.concat(out)
end

return C
