local lift_strings = require "titan-compiler.lift_strings"

local ast = require "titan-compiler.ast"
local builtins = require "titan-compiler.builtins"

local function run_lift_strings(code)
    local prog, errs = lift_strings.lift("(lift_strings_spec)", code)
    return prog, table.concat(errs, "\n")
end

describe("Lift Strings: ", function()
    it("works", function()
        local prog, errs = run_lift_strings([[
            function f(): string
                return "Hello"
            end
        ]])

        assert.truthy(prog)

        assert.are.equal(2, #prog)

        assert.are.equal(ast.Toplevel.Var, prog[1]._tag)
        assert.are.equal("<string_literal_1>", prog[1].decl.name)

        assert.are.equal(ast.Toplevel.Func, prog[2]._tag)
        assert.are.equal("<string_literal_1>",
            prog[2].block.stats[1].exps[1].var.name)
    end)
end)


