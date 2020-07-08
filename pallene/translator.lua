local translator = {}

local function translate_expression(expression)
    if expression._tag == "ast.Exp.Integer" then
        io.write(expression.value)
    end
end

local function translate_tl_var(node)
    io.write('local ')
    for _, declaration in pairs(node.decls) do
        io.write(declaration.name)
    end

    if #node.values > 0 then
        io.write(' = ')
        for _, value in pairs(node.values) do
            translate_expression(value)
        end
    end

    io.write('\n')
end

local function add_previous(input, partials, start_index, stop_index)
    local partial = input:sub(start_index, stop_index)
    table.insert(partials, partial)
    return stop_index
end

-- TODO: Added test case for newlines, space, comments, and tabs.

local function add_whitespace(input, partials, start_index, stop_index)
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

    return stop_index
end

function translator.translate(input, prog_ast)        
    print(require('inspect')(prog_ast))

    local partials = {}
    local last_index = 1
    for _, node in pairs(prog_ast) do
        if node._tag == "ast.Toplevel.Var" then
            local start = node.decls[1].type_start.pos
            local stop = node.decls[1].type_end.pos
            
            last_index = add_previous(input, partials, last_index, start - 1)
            last_index = add_whitespace(input, partials, start, stop - 1)
        end
    end
    -- Whatever characters that were not included in the partials should be added.
    -- local final_partial = input:sub(last_index)
    -- table.insert(partials, final_partial)
    add_previous(input, partials, last_index, nil)

    return table.concat(partials, "")
end

return translator
