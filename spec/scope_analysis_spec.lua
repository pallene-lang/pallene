local scope_analysis = require 'titan-compiler.scope_analysis'

local function run_scope_analysis(code)
    local prog, errs = scope_analysis.bind_names("(scope_analysis_spec)", code)
    return prog, table.concat(errs, "\n")
end

describe("Scope analysis: ", function()

    it("global variables work", function()
        local prog, errs = run_scope_analysis([[
            local x: integer = 10
            function fn(): integer
                return x
            end
        ]])
        assert.truthy(prog)
        assert.are.equal(
            prog[1], -- x
            prog[2].block.stats[1].exp.var._decl)
    end)

    it("function parameters work", function()
        local prog, errs = run_scope_analysis([[
            function fn(x: integer): integer
                return x
            end
        ]])
        assert.truthy(prog)
        assert.are.equal(
            prog[1].params[1], -- x
            prog[1].block.stats[1].exp.var._decl)
    end)

    it("local variables work", function()
        local prog, errs = run_scope_analysis([[
            function fn(): integer
                local x = 17
                return x
            end
        ]])
        assert.truthy(prog)
        assert.are.equal(
            prog[1].block.stats[1].decl, -- x
            prog[1].block.stats[2].exp.var._decl)
    end)

    it("functions can be recursive", function()
        local prog, errs = run_scope_analysis([[
            function fac(n: integer): integer
                if n == 0 then
                    return 1
                else
                    return n * fac(n-1)
                end
            end
        ]])
        assert.truthy(prog)
        assert.are.equal(
            prog[1], -- fac
            prog[1].block.stats[1].elsestat.stats[1].exp.rhs.exp.var._decl)
    end)

    it("forbids variables from being used before they are defined", function()
        local prog, errs = run_scope_analysis([[
            function fn(): nil
                x = 17
                local x = 18
            end
        ]])
        assert.falsy(prog)
        assert.match("variable 'x' is not declared", errs)
    end)

    it("forbids type variables from being used before they are defined", function()
        local prog, errs = run_scope_analysis([[
            function fn(p: Point): integer
                return p.x
            end

            record Point
                x: integer
                y: integer
            end
        ]])
        assert.falsy(prog)
        assert.match("type 'Point' is not declared", errs)
    end)

    it("do-end limits variable scope", function()
        local prog, errs = run_scope_analysis([[
            function fn(): nil
                do
                    local x = 17
                end
                x = 18
            end
        ]])
        assert.falsy(prog)
        assert.match("variable 'x' is not declared", errs)
    end)

    it("local variable scope doesn't shadow its type annotation", function()
        local prog, errs = run_scope_analysis([[
            record x
                x: integer
                y: integer
            end

            function fn(): integer
                local x: x = { x=1, y=2 }
                return x.x
            end
        ]])
        assert.truthy(prog)
        assert.are.equal(
            prog[1], -- global x
            prog[2].block.stats[1].decl.type._decl)
        assert.are.equal(
            prog[2].block.stats[1].decl, -- local x
            prog[2].block.stats[2].exp.var.exp.var._decl)
    end)

    it("local variable scope doesn't shadow its initializer", function()
        local prog, errs = run_scope_analysis([[
            local x = 17
            function fn(): integer
                local x = x + 1
                return x
            end
        ]])
        assert.truthy(prog)
        assert.are.equal(
            prog[1], -- global x
            prog[2].block.stats[1].exp.lhs.var._decl)
        assert.are.equal(
            prog[2].block.stats[1].decl, -- local x
            prog[2].block.stats[2].exp.var._decl)
    end)

    it("repeat-until scope includes the condition", function()
        local prog, errs = run_scope_analysis([[
            function fn(): integer
                local x = 0
                repeat
                    x = x + 1
                    local limit = x * 10
                until limit >= 100
                return x
            end
        ]])
        assert.truthy(prog)
        assert.are.equal(
            prog[1].block.stats[2].block.stats[2].decl, -- local limit
            prog[1].block.stats[2].condition.lhs.var._decl)
    end)

    it("for loop variable scope doesn't shadow its type annotation", function()
        local prog, errs = run_scope_analysis([[
            record x
                x: integer
                y: integer
            end
            function fn(): integer
                for x: x = 1, 10 do
                   return x
                end
            end
        ]])
        assert.truthy(prog)
        assert.are.equal(
            prog[1], -- global x
            prog[2].block.stats[1].decl.type._decl)
        assert.are.equal(
            prog[2].block.stats[1].decl, -- local x
            prog[2].block.stats[1].block.stats[1].exp.var._decl)
    end)

    it("for loop variable scope doesn't shadow its initializers", function()
        local prog, errs = run_scope_analysis([[
            function fn(): integer
                local x = 10
                for x: integer = x, x, x do
                   return x
                end
            end
        ]])
        assert.truthy(prog)
        assert.are.equal(
            prog[1].block.stats[1].decl, -- local x
            prog[1].block.stats[2].start.var._decl)
        assert.are.equal(
            prog[1].block.stats[1].decl,
            prog[1].block.stats[2].finish.var._decl)
        assert.are.equal(
            prog[1].block.stats[1].decl,
            prog[1].block.stats[2].inc.var._decl)
        assert.are.equal(
            prog[1].block.stats[2].decl, -- for x
            prog[1].block.stats[2].block.stats[1].exp.var._decl)
    end)

    it("allows recursive functions", function()
        local prog, errs = run_scope_analysis([[
            local function fat(n: integer): integer
                if n == 0 then
                    return 1
                else
                    return n * fat(n - 1)
                end
            end
        ]])
        assert.truthy(prog)
        assert.are.equal(
            prog[1], -- fat
            prog[1].block.stats[1].elsestat.stats[1].exp.rhs.exp.var._decl)
    end)

    it("forbids mutually recursive definitions", function()
        local prog, errs = run_scope_analysis([[
            local function foo(): integer
                return bar()
            end

            local function bar(): integer
                return foo()
            end
        ]])
        assert.falsy(prog)
        assert.match("variable 'bar' is not declared", errs)
    end)

    it("forbids multiple toplevel declarations with the same name", function()
        local prog, errs = run_scope_analysis([[
            local x: integer = 10
            local x: integer = 11
        ]])
        assert.falsy(prog)
        assert.match("duplicate toplevel declaration", errs)
    end)

    it("forbids multiple function arguments with the same name", function()
        local prog, errs = run_scope_analysis([[
            function fn(x: integer, x:string)
            end
        ]])
        assert.falsy(prog)
        assert.match("function 'fn' has multiple parameters named 'x'", errs)
    end)

    it("detects when a non-type is used in a type variable", function()
        local prog, errs = run_scope_analysis([[
            local foo: integer = 10
            local bar: foo = 11
        ]])
        assert.falsy(prog)
        assert.match("'foo' isn't a type", errs)
    end)

    it("detects when a non-value is used in a value variable", function()
        local prog, errs = run_scope_analysis([[
            record Point
                x: integer
                y: integer
            end
            local bar: integer = Point
        ]])
        assert.falsy(prog)
        assert.match("'Point' isn't a value", errs)
    end)

end)
