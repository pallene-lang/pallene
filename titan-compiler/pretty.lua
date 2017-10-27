local pretty = {}

function pretty.reindent_c(input)
    local out = {}
    local indent = 0
    local blank = false
    for line in input:gmatch("([^\n]*)") do
        local do_print = true
        line = line:match("^[ \t]*(.-)[ \t]*$")
        if #line == 0 then
            if blank or indent > 0 then
                do_print = false
            else
                blank = true
            end
        else
            blank = false
        end
        if line:match("^}") then
            indent = indent - 1
        end
        if do_print then
            table.insert(out, ("    "):rep(indent) .. line)
        end
        if line:match("{$") then
            indent = indent + 1
        end
    end
    return table.concat(out, "\n") .. "\n"
end

return pretty
