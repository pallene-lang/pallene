local pretty = {}

-- This pretty printer allows us generate readable C code without needing to
-- worry about indenting it as we generate it.
--
-- To keep the implementation simple, we assume that the input C code conforms
-- to our style guide for generated C code, which is described here. The
-- important bit is ensuring that our heuristics can correctly identify when to
-- indent and unindent based solely on the position of {} and () characters in
-- the input program.
--
-- COMMENTS:
--     - Prefer /**/-style comments over //-style comments
--     - Never place inline comments just after a {
--     - Comments should not span multiple lines
--     - Don't put user-generated text inside comments
--     - Don't put C code inside comments
--
--         /* This is */
--         /* allowed */
--         if (x == y) {
--         }
--
--         if (x == y) { /* This is very bad */
--         }
--
--         /* Don't
--          * do this */
--
-- INDENTATION
--     - Use K&R-style indentation
--     - Multi-line statements must use braces
--
--         /* OK */
--         if (x == y) {
--             blah();
--         }
--
--         /* BAD */
--         if (x == y)
--             blah();

function pretty.reindent_c(input)
    local out = {}
    local indent = 0
    local previous_is_blank = true
    for line in input:gmatch("([^\n]*)") do
        line = line:match("^[ \t]*(.-)[ \t]*$")

        local is_blank = (#line == 0)
        local do_print =
            (not is_blank) or
            (not previous_is_blank and indent == 0)

        if line:match("^[})]") then
            indent = indent - 1
            -- Don't let the indentation level get negative. This confines the
            -- messed-up indentation to a single function in cases where our
            -- heuristics have failed to spot the "{" that matches this "}"
            if indent < 0 then indent = 0 end
        end
        if do_print then
            table.insert(out, string.rep("    ", indent))
            table.insert(out, line)
            table.insert(out, "\n")
        end
        if line:match("[{(]$") then
            indent = indent + 1
        end

        previous_is_blank = is_blank
    end
    return table.concat(out)
end

return pretty
