local translator = {}

local last_index = 1

local function add_previous(input, partials, stop_index)
    local partial = input:sub(last_index, stop_index)
    table.insert(partials, partial)

    -- Do not update the last index if this is the last call to add_previous.
    if stop_index then
        last_index = stop_index + 1
    end
end

-- TODO: Added test case for newlines, space, comments, and tabs.

local function add_whitespace(input, partials, start_index, stop_index)
    add_previous(input, partials, start_index - 1)

    local p = start_index
    local q = start_index
    while q <= stop_index do
        if input:sub(q, q) == "\n" then
            local partial = string.rep(" ", q - p - 1)
            table.insert(partials, partial)
            table.insert(partials, "\n")
            p = q + 2
        end
        q = q + 1
    end
    local final_partial = string.rep(" ", q - p)
    table.insert(partials, final_partial)

    last_index = stop_index + 1
end

function translator.translate(input, prog_ast)        
    -- print(require('inspect')(prog_ast))

    local partials = {}
    for _, node in ipairs(prog_ast) do
        if node._tag == "ast.Toplevel.Var" then
            for _, decl in ipairs(node.decls) do
                local start = decl.type_start.pos
                local stop = decl.type_end.pos
                
                add_whitespace(input, partials, start, stop - 1)
            end
        end
    end
    -- Whatever characters that were not included in the partials should be added.
    -- local final_partial = input:sub(last_index)
    -- table.insert(partials, final_partial)
    add_previous(input, partials, nil)

    return table.concat(partials, "")
end

return translator
