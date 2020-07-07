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

local function add_whitespace(input, partials, start_index, stop_index)
    local partial = string.rep(' ', stop_index - start_index)
    -- TODO: Correctly handle newlines
    table.insert(partials, partial)
    return stop_index
end

function translator.translate(input, prog_ast)
    local partials = {}
    local last_index = 1
    for _, node in pairs(prog_ast) do
        if node._tag == "ast.Toplevel.Var" then
            local start = node.decls[1].type_start.col
            local stop = node.decls[1].type_end.col
            
            last_index = add_previous(input, partials, last_index, start - 1)
            last_index = add_whitespace(input, partials, start, stop)
        end
    end
    -- Whatever characters that were not included in the partials should be added.
    local final_partial = input:sub(last_index)
    table.insert(partials, final_partial)
    
    print('--------------------')
    print(require('inspect')(prog_ast))

    return table.concat(partials, "")
end

return translator
