local checker = require "titan-compiler.checker"

local coder = {}

local generate_program

function coder.generate(filename, input)
    local ast, errors = checker.check(filename, input)
    if not ast then return false, errors end
    local code = generate_program(ast)
    return code, errors
end

generate_program = function() return "" end

return coder
