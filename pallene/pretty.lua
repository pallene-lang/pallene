local pretty = {}

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
function pretty.reindent_c(input)
    local out = {}
    local indent = 0
    local previous_is_blank = true
    for line in input:gmatch("([^\n]*)") do
        line = line:match("^[ \t]*(.-)[ \t]*$")

        -- Inside functions ignore all empty lines. In the toplevel, collapse
        -- groups of empty lines between declarations into a single empty line.
        local is_blank = (#line == 0)
        if (not is_blank) or (indent == 0 and not previous_is_blank) then

            local indent_for_this_line
            if line:match("^#") then
                -- Preprocessor directives are never indented
                indent_for_this_line = 0
            else
                -- Otherwise, count braces and parens
                local without_strings = line:gsub('\\\"', "")
                                            :gsub('".-"', "")
                local without_comments = without_strings:gsub("/%*.-%*/", "")
                                                        :gsub("//.*", "")
                local n_open  = #string.gsub(without_comments, "[^{(]", "")
                local n_close = #string.gsub(without_comments, "[^})]", "")
                local unindent_this_line = string.match(line, "^[})]")

                indent_for_this_line = indent - (unindent_this_line and 1 or 0)

                if     n_open > n_close then
                    indent = indent + 1
                elseif n_open < n_close then
                    indent = indent - 1
                end

                if indent < 0 then
                    -- Don't let the indentation level get negative. If by any
                    -- chance our heuristics fail to spot an open brace or
                    -- paren, this confines the messed up indentation to a
                    -- single function.
                    indent = 0
                end
            end

            table.insert(out, string.rep("    ", indent_for_this_line))
            table.insert(out, line)
            table.insert(out, "\n")
        end
        previous_is_blank = is_blank
    end
    return table.concat(out)
end

return pretty
