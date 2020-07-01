local translator = {}

function translator.translate(input, module)
    print(require('inspect')(module))
    return input
end

return translator
