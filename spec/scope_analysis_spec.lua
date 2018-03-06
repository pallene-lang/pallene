local parser = require 'titan-compiler.parser'
local scope_analysis = require 'titan-compiler.scope_analysis'

local function run_scope_analysis(code)
    local prog, errs
    prog = assert(parser.parse("(scope_analysis_spec)", code))
    prog, errs = scope_analysis.bind_names(prog)
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
        assert.match("variable 'x' not declared", errs)
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
        assert.match("variable 'x' not declared", errs)
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

    it("allows mutually-recursive toplevel definitions", function()
        local prog, errs = run_scope_analysis([[
            function f(): integer
                return g() + p.x.n
            end

            function g(): integer
                return f() + p.x.n
            end

            record BoxyPoint
                x: IntBox
                y: IntBox
            end

            record IntBox
                n: integer
            end

            local p: BoxyPoint = { x = { n = 1 }, y = { n = 2 } }
        ]])
        assert.truthy(prog)

        -- function f
        assert.are.equal(
            prog[1],
            prog[2].block.stats[1].exp.lhs.exp.var._decl)

        -- function g
        assert.are.equal(
            prog[2],
            prog[1].block.stats[1].exp.lhs.exp.var._decl)

        -- record BoxyPoint
        assert.are.equal(
            prog[3],
            prog[5].decl.type._decl)

        -- record IntBox
        assert.are.equal(
            prog[4],
            prog[3].field_decls[1].type._decl)
        assert.are.equal(
            prog[4],
            prog[3].field_decls[2].type._decl)

        -- local p
        assert.are.equal(
            prog[5],
            prog[1].block.stats[1].exp.rhs.var.exp.var.exp.var._decl)
        assert.are.equal(
            prog[5],
            prog[2].block.stats[1].exp.rhs.var.exp.var.exp.var._decl)
    end)

    it("forbids multiple toplevel declarations with the same name", function()
        local prog, errs = run_scope_analysis([[
            local x: integer = 10
            local x: integer = 11
        ]])
        assert.falsy(prog)
        assert.match("duplicate toplevel declaration", errs)
    end)
end)
