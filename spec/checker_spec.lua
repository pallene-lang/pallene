local checker = require 'titan-compiler.checker'
local parser = require 'titan-compiler.parser'
local types = require 'titan-compiler.types'

describe("Titan type checker", function()

    it("detects invalid types", function()
        local code = [[
            function fn(): foo
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.falsy(ok)
        assert.match("type name foo is invalid", err)
    end)

    it("coerces to integer", function()
        local code = [[
            function fn(): integer
                local f: float = 1.0
                local i: integer = f
                return 1
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok)
        assert.same("Exp_ToInt", ast[1].block.stats[2].exp._tag)
    end)

    it("coerces to float", function()
        local code = [[
            function fn(): integer
                local i: integer = 12
                local f: float = i
                return 1
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok)
        assert.same("Exp_ToFloat", ast[1].block.stats[2].exp._tag)
    end)

    it("catches duplicate declartions", function()
        local code = [[
            function fn(): integer
                return 1
            end
            function fn(): integer
                return 1
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.falsy(ok)
        assert.match("duplicate function", err)
    end)
    
    it("catches mismatching types in locals", function()
        local code = [[
            function fn(): nil
                local i: integer = 1
                local s: string = "foo"
                s = i
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.falsy(ok)
        assert.match("expected string but found integer", err)
    end)

    it("catches mismatching types in arguments", function()
        local code = [[
            function fn(i: integer, s: string): integer
                s = i
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.falsy(ok)
        assert.match("expected string but found integer", err)
    end)

    it("allows setting element of array as nil", function ()
        local code = [[
            function fn(): nil
                local arr: {integer} = { 10, 20, 30 }
                arr[1] = nil
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
    end)

    it("type-checks 'for'", function()
        local code = [[
            function fn(x: integer): integer
                for i = 1, 10 do
                    x = x + i
                end
                return x
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok)
    end)

    it("type-checks 'for'", function()
        local code = [[
            function fn(x: integer): integer
                local i: integer = 0
                for i = 1, 10 do
                    x = x + i
                end
                return x
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok)
    end)

    it("type-checks 'while'", function()
        local code = [[
            function fn(x: integer): integer
                local i: integer = 15
                while x < 100 do
                    x = x + i
                end
                return x
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok)
    end)

    it("type-checks 'if'", function()
        local code = [[
            function fn(x: integer): integer
                local i: integer = 15
                if x < 100 then
                    x = x + i
                elseif x > 100 then
                    x = x - i
                else
                    x = 100
                end
                return x
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok)
    end)

    it("checks code inside the 'while' black", function()
        local code = [[
            function fn(x: integer): integer
                local i: integer = 15
                while i do
                    local s: string = i
                end
                return x
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.falsy(ok)
        assert.match("expected string but found integer", err)
    end)

    it("type-checks 'for' with a step", function()
        local code = [[
            function fn(x: integer): integer
                local i: integer = 0
                for i = 1, 10, 2 do
                    x = x + i
                end
                return x
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok)
    end)

    it("catches 'for' errors in the start expression", function()
        local code = [[
            function fn(x: integer, s: string): integer
                local i: integer = 0
                for i = s, 10, 2 do
                    x = x + i
                end
                return x
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.falsy(ok)
        assert.match("'for' start expression", err)
    end)

    it("catches 'for' errors in the control variable", function()
        local code = [[
            function fn(x: integer, s: string): integer
                for i: string = 1, s, 2 do
                    x = x + i
                end
                return x
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.falsy(ok)
        assert.match("control variable", err)
    end)

    it("catches 'for' errors in the finish expression", function()
        local code = [[
            function fn(x: integer, s: string): integer
                local i: integer = 0
                for i = 1, s, 2 do
                    x = x + i
                end
                return x
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.falsy(ok)
        assert.match("'for' finish expression", err)
    end)

    it("catches 'for' errors in the step expression", function()
        local code = [[
            function fn(x: integer, s: string): integer
                local i: integer = 0
                for i = 1, 10, s do
                    x = x + i
                end
                return x
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.falsy(ok)
        assert.match("'for' step expression", err)
    end)

    it("detects nil returns on non-nil functions", function()
        local code = [[
            function fn(): integer
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.falsy(ok)
        assert.match("function can return nil", err)
    end)

    for _, op in ipairs({"==", "~=", "<", ">", "<=", ">="}) do
        it("coerces "..op.." to float if any side is a float", function()
            local code = [[
                function fn(): integer
                    local i: integer = 1
                    local f: float = 1.5
                    local i_f = i ]] .. op .. [[ f
                    local f_i = f ]] .. op .. [[ i
                    local f_f = f ]] .. op .. [[ f
                    local i_i = i ]] .. op .. [[ i
                end
            ]]
            local ast, err = parser.parse(code)
            checker.check(ast, code, "test.titan")

            assert.same(types.Float, ast[1].block.stats[3].exp.lhs._type)
            assert.same(types.Float, ast[1].block.stats[3].exp.rhs._type)
            assert.same(types.Boolean, ast[1].block.stats[3].exp._type)

            assert.same(types.Float, ast[1].block.stats[4].exp.lhs._type)
            assert.same(types.Float, ast[1].block.stats[4].exp.rhs._type)
            assert.same(types.Boolean, ast[1].block.stats[4].exp._type)

            assert.same(types.Float, ast[1].block.stats[5].exp.lhs._type)
            assert.same(types.Float, ast[1].block.stats[5].exp.rhs._type)
            assert.same(types.Boolean, ast[1].block.stats[5].exp._type)

            assert.same(types.Integer, ast[1].block.stats[6].exp.lhs._type)
            assert.same(types.Integer, ast[1].block.stats[6].exp.rhs._type)
            assert.same(types.Boolean, ast[1].block.stats[6].exp._type)
        end)
    end

    for _, op in ipairs({"+", "-", "*", "%", "//"}) do
        it("coerces "..op.." to float if any side is a float", function()
            local code = [[
                function fn(): integer
                    local i: integer = 1
                    local f: float = 1.5
                    local i_f = i ]] .. op .. [[ f
                    local f_i = f ]] .. op .. [[ i
                    local f_f = f ]] .. op .. [[ f
                    local i_i = i ]] .. op .. [[ i
                end
            ]]
            local ast, err = parser.parse(code)
            checker.check(ast, code, "test.titan")

            assert.same(types.Float, ast[1].block.stats[3].exp.lhs._type)
            assert.same(types.Float, ast[1].block.stats[3].exp.rhs._type)
            assert.same(types.Float, ast[1].block.stats[3].exp._type)

            assert.same(types.Float, ast[1].block.stats[4].exp.lhs._type)
            assert.same(types.Float, ast[1].block.stats[4].exp.rhs._type)
            assert.same(types.Float, ast[1].block.stats[4].exp._type)

            assert.same(types.Float, ast[1].block.stats[5].exp.lhs._type)
            assert.same(types.Float, ast[1].block.stats[5].exp.rhs._type)
            assert.same(types.Float, ast[1].block.stats[5].exp._type)

            assert.same(types.Integer, ast[1].block.stats[6].exp.lhs._type)
            assert.same(types.Integer, ast[1].block.stats[6].exp.rhs._type)
            assert.same(types.Integer, ast[1].block.stats[6].exp._type)
        end)
    end

    for _, op in ipairs({"/", "^"}) do
        it("always coerces "..op.." to float", function()
            local code = [[
                function fn(): integer
                    local i: integer = 1
                    local f: float = 1.5
                    local i_f = i ]] .. op .. [[ f
                    local f_i = f ]] .. op .. [[ i
                    local f_f = f ]] .. op .. [[ f
                    local i_i = i ]] .. op .. [[ i
                end
            ]]
            local ast, err = parser.parse(code)
            checker.check(ast, code, "test.titan")

            assert.same(types.Float, ast[1].block.stats[3].exp.lhs._type)
            assert.same(types.Float, ast[1].block.stats[3].exp.rhs._type)
            assert.same(types.Float, ast[1].block.stats[3].exp._type)

            assert.same(types.Float, ast[1].block.stats[4].exp.lhs._type)
            assert.same(types.Float, ast[1].block.stats[4].exp.rhs._type)
            assert.same(types.Float, ast[1].block.stats[4].exp._type)

            assert.same(types.Float, ast[1].block.stats[5].exp.lhs._type)
            assert.same(types.Float, ast[1].block.stats[5].exp.rhs._type)
            assert.same(types.Float, ast[1].block.stats[5].exp._type)

            assert.same(types.Float, ast[1].block.stats[6].exp.lhs._type)
            assert.same(types.Float, ast[1].block.stats[6].exp.rhs._type)
            assert.same(types.Float, ast[1].block.stats[6].exp._type)
        end)
    end

    pending("cannot concatenate with boolean", function()
        local code = [[
            function fn(): nil
                local s = "foo" .. true
            end
        ]]
        local ast, err = parser.parse(code)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.falsy(ok)
        assert.match("cannot concatenate with boolean value", err)
    end)

end)

