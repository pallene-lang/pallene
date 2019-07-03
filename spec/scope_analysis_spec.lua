local driver = require "pallene.driver"
local util = require "pallene.util"

local function run_scope_analysis(code)
    assert(util.set_file_contents("test.pln", code))
    local prog_ast, errs = driver.test_ast("scope_analysis", "test.pln")
    return prog_ast, table.concat(errs, "\n")
end

describe("Scope analysis: ", function()

    teardown(function()
        os.remove("test.pln")
    end)

    it("forbids variables from being used before they are defined", function()
        local prog_ast, errs = run_scope_analysis([[
            function fn(): nil
                x = 17
                local x = 18
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("variable 'x' is not declared", errs)
    end)

    it("forbids type variables from being used before they are defined", function()
        local prog_ast, errs = run_scope_analysis([[
            function fn(p: Point): integer
                return p.x
            end

            record Point
                x: integer
                y: integer
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("type 'Point' is not declared", errs)
    end)

    it("do-end limits variable scope", function()
        local prog_ast, errs = run_scope_analysis([[
            function fn(): nil
                do
                    local x = 17
                end
                x = 18
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("variable 'x' is not declared", errs)
    end)

    it("repeat-until scope includes the condition", function()
        local prog_ast, errs = run_scope_analysis([[
            function fn(): integer
                local x = 0
                repeat
                    x = x + 1
                    local limit = x * 10
                until limit >= 100
                return x
            end
        ]])
        assert(prog_ast, errs)
        assert.are.equal(
            prog_ast[1].block.stats[2].block.stats[2].decl, -- local limit
            prog_ast[1].block.stats[2].condition.lhs.var._decl)
    end)

    it("forbids mutually recursive definitions", function()
        local prog_ast, errs = run_scope_analysis([[
            local function foo(): integer
                return bar()
            end

            local function bar(): integer
                return foo()
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("variable 'bar' is not declared", errs)
    end)

    it("forbids multiple toplevel declarations with the same name", function()
        local prog_ast, errs = run_scope_analysis([[
            local x: integer = 10
            local x: integer = 11
        ]])
        assert.falsy(prog_ast)
        assert.match("duplicate toplevel declaration", errs)
    end)

    it("forbids multiple function arguments with the same name", function()
        local prog_ast, errs = run_scope_analysis([[
            function fn(x: integer, x:string)
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("function 'fn' has multiple parameters named 'x'", errs)
    end)
end)
