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

function translator.translate(input, ast)
    for _, node in pairs(ast) do
        if node._tag == "ast.Toplevel.Var" then
            local start = node.decls[1].type_start.col
            local stop = node.decls[1].type_end.col
            print(input:sub(1, start - 1) .. string.rep(' ', stop - start)
                .. input:sub(stop))
        end
    end
    print('--------------------')
    print(require('inspect')(ast))
    return input
end

return translator
