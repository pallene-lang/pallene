local checker = require 'titan-compiler.checker'
local parser = require 'titan-compiler.parser'
local types = require 'titan-compiler.types'

local function run_checker(code)
    local ast = assert(parser.parse(code))
    local _, err = checker.check("test", ast, code, "test.titan")
    return err == nil, err, ast
end

-- Return a version of t2 that only contains fields present in t1 (recursively)
-- Example:
--   t1  = { b = { c = 10 } e = 40 }
--   t2  = { a = 1, b = { c = 20, d = 30} }
--   out = { b = { c = 20 } }
local function restrict(t1, t2)
    if type(t1) == 'table' and type(t2) == 'table' then
        local out = {}
        for k,_ in pairs(t1) do
            out[k] = restrict(t1[k], t2[k])
        end
        return out
    else
        return t2
    end
end

-- To avoid having these tests break all the time when we make insignificant
-- changes to the AST, we only verify a subset of the AST.
local function assert_ast(program, expected)
    local received = restrict(expected, program)
    assert.are.same(expected, received)
end

describe("Titan type checker", function()

    it("detects invalid types", function()
        local code = [[
            function fn(): foo
            end
        ]]
        local ok, err = run_checker(code)
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
        local ok, err, ast = run_checker(code)
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
        local ok, err, ast = run_checker(code)
        assert.truthy(ok)
        assert.same("Exp_ToFloat", ast[1].block.stats[2].exp._tag)
    end)

    it("catches duplicate function declarations", function()
        local code = [[
            function fn(): integer
                return 1
            end
            function fn(): integer
                return 1
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("duplicate function", err)
    end)

    it("catches duplicate variable declarations", function()
        local code = {[[
            local x = 1
            x = 2
        ]],
        [[
            local x: integer = 1
            x = 2
        ]],
        }
        for _, c in ipairs(code) do
            local ok, err = run_checker(c)
            assert.falsy(ok)
            assert.match("duplicate variable", err)
        end
    end)

    it("catches variable not declared", function()
        local code = [[
            function fn(): nil
                local x:integer = 1
                y = 2
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("variable '%w+' not declared", err)
    end)

    it("catches reference to function", function()
        local code = [[
            function fn(): nil
                fn = 1
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("reference to function", err)
    end)

    it("catches array expression in indexing is not an array", function()
        local code = [[
            function fn(x: integer): nil
                x[1] = 2
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("array expression in indexing is not an array", err)
    end)

    it("catches wrong use of length operator", function()
        local code = [[
            function fn(x: integer): integer
                return #x
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("trying to take the length", err)
    end)

    it("catches wrong use of unary minus", function()
        local code = [[
            function fn(x: boolean): boolean
                return -x
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("trying to negate a", err)
    end)

    it("catches wrong use of bitwise not", function()
        local code = [[
            function fn(x: boolean): boolean
                return ~x
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("trying to bitwise negate a", err)
    end)

    it("catches mismatching types in locals", function()
        local code = [[
            function fn(): nil
                local i: integer = 1
                local s: string = "foo"
                s = i
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("expected string but found integer", err)
    end)

    it("function can call another function", function()
        local code = [[
            function fn1(): nil
              fn2()
            end

            function fn2(): nil
            end
        ]]
        local ok, err = run_checker(code)
        assert.truthy(ok)
    end)

    it("catches mismatching types in arguments", function()
        local code = [[
            function fn(i: integer, s: string): integer
                s = i
            end
        ]]
        local ok, err = run_checker(code)
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
        local ok, err = run_checker(code)
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
        local ok, err = run_checker(code)
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
        local ok, err = run_checker(code)
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
        local ok, err = run_checker(code)
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
        local ok, err = run_checker(code)
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
        local ok, err = run_checker(code)
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
        local ok, err = run_checker(code)
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
        local ok, err = run_checker(code)
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
        local ok, err = run_checker(code)
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
        local ok, err = run_checker(code)
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
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("'for' step expression", err)
    end)

    it("detects nil returns on non-nil functions", function()
        local code = {[[
            function fn(): integer
            end
        ]],
        [[
            function getval(a:integer): integer
                if a == 1 then
                    return 10
                elseif a == 2 then
                else
                    return 30
                end
            end
        ]],
        [[
            function getval(a:integer): integer
                if a == 1 then
                    return 10
                elseif a == 2 then
                    return 20
                else
                    if a < 5 then
                        if a == 3 then
                            return 30
                        end
                    else
                        return 50
                    end
                end
            end
        ]],
        }
        for _, c in ipairs(code) do
            local ok, err = run_checker(c)
            assert.falsy(ok)
            assert.match("function can return nil", err)
        end
    end)

    it("detects attempts to call non-functions", function()
        local code = [[
            function fn(): integer
                local i: integer = 0
                i()
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("is not a function", err)
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
            local ok, err, ast = run_checker(code)

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
            local ok, err, ast = run_checker(code)

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
            local ok, err, ast = run_checker(code)

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

    it("cannot concatenate with boolean", function()
        local code = [[
            function fn(): nil
                local s = "foo" .. true
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("cannot concatenate with boolean value", err)
    end)

    it("cannot concatenate with nil", function()
        local code = [[
            function fn(): nil
                local s = "foo" .. nil
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("cannot concatenate with nil value", err)
    end)

    it("cannot concatenate with array", function()
        local code = [[
            function fn(): nil
                local s = "foo" .. {}
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("cannot concatenate with { integer } value", err)
    end)

    it("cannot concatenate with boolean", function()
        local code = [[
            function fn(): nil
                local s = "foo" .. true
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("cannot concatenate with boolean value", err)
    end)

    it("can concatenate with integer and float", function()
        local code = [[
            function fn(): nil
                local s = 1 .. 2.5
            end
        ]]
        local ok, err = run_checker(code)
        assert.truthy(ok)
    end)

    for _, op in ipairs({"==", "~="}) do
        it("can compare arrays of same type using " .. op, function()
            local code = [[
                function fn(a1: {integer}, a2: {integer}): boolean
                    return a1 ]] .. op .. [[ a2
                end
            ]]
            local ok, err = run_checker(code)
            assert.truthy(ok)
        end)
    end

    for _, op in ipairs({"==", "~="}) do
        it("can compare booleans using " .. op, function()
            local code = [[
                function fn(b1: string, b2: string): boolean
                    return b1 ]] .. op .. [[ b2
                end
            ]]
            local ok, err = run_checker(code)
            assert.truthy(ok)
        end)
    end

    for _, op in ipairs({"==", "~=", "<", ">", "<=", ">="}) do
        it("can compare floats using " .. op, function()
            local code = [[
                function fn(f1: string, f2: string): boolean
                    return f1 ]] .. op .. [[ f2
                end
            ]]
            local ok, err = run_checker(code)
            assert.truthy(ok)
        end)
    end

    for _, op in ipairs({"==", "~=", "<", ">", "<=", ">="}) do
        it("can compare integers using " .. op, function()
            local code = [[
                function fn(i1: string, i2: string): boolean
                    return i1 ]] .. op .. [[ i2
                end
            ]]
            local ok, err = run_checker(code)
            assert.truthy(ok)
        end)
    end

    for _, op in ipairs({"==", "~=", "<", ">", "<=", ">="}) do
        it("can compare integers and floats using " .. op, function()
            local code = [[
                function fn(i: integer, f: float): boolean
                    return i ]] .. op .. [[ f
                end
            ]]
            local ok, err = run_checker(code)
            assert.truthy(ok)
        end)
    end

    for _, op in ipairs({"==", "~=", "<", ">", "<=", ">="}) do
        it("can compare strings using " .. op, function()
            local code = [[
                function fn(s1: string, s2: string): boolean
                    return s1 ]] .. op .. [[ s2
                end
            ]]
            local ok, err = run_checker(code)
            assert.truthy(ok)
        end)
    end

    for _, op in ipairs({"==", "~="}) do
        it("cannot compare arrays of different types using " .. op, function()
            local code = [[
                function fn(a1: {integer}, a2: {float}): boolean
                    return a1 ]] .. op .. [[ a2
                end
            ]]
            local ok, err = run_checker(code)
            assert.falsy(ok)
            assert.match("trying to compare values of different types", err)
        end)
    end

    for _, op in ipairs({"==", "~="}) do
        for _, t1 in ipairs({"{integer}", "boolean", "float", "string"}) do
            for _, t2 in ipairs({"{integer}", "boolean", "float", "string"}) do
                if t1 ~= t2 then
                    it("cannot compare " .. t1 .. " and " .. t2 .. " using " .. op, function()
                        local code = [[
                            function fn(a: ]] .. t1 .. [[, b: ]] .. t2 .. [[): boolean
                                return a ]] .. op .. [[ b
                            end
                        ]]
                        local ok, err = run_checker(code)
                        assert.falsy(ok)
                        assert.match("trying to compare values of different types", err)
                    end)
                end
            end
        end
    end

    for _, op in ipairs({"==", "~="}) do
        for _, t1 in ipairs({"{integer}", "boolean", "integer", "string"}) do
            for _, t2 in ipairs({"{integer}", "boolean", "integer", "string"}) do
                if t1 ~= t2 then
                    it("cannot compare " .. t1 .. " and " .. t2 .. " using " .. op, function()
                        local code = [[
                            function fn(a: ]] .. t1 .. [[, b: ]] .. t2 .. [[): boolean
                                return a ]] .. op .. [[ b
                            end
                        ]]
                        local ok, err = run_checker(code)
                        assert.falsy(ok)
                        assert.match("trying to compare values of different types", err)
                    end)
                end
            end
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot compare " .. t .. " and float using " .. op, function()
                local code = [[
                    function fn(a: ]] .. t .. [[, b: float): boolean
                        return a ]] .. op .. [[ b
                    end
                ]]
                local ok, err = run_checker(code)
                assert.falsy(ok)
                assert.match("left hand side of relational expression is", err)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot compare float and " .. t .. " using " .. op, function()
                local code = [[
                    function fn(a: float, b: ]] .. t .. [[): boolean
                        return a ]] .. op .. [[ b
                    end
                ]]
                local ok, err = run_checker(code)
                assert.falsy(ok)
                assert.match("right hand side of relational expression is", err)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot compare " .. t .. " and integer using " .. op, function()
                local code = [[
                    function fn(a: ]] .. t .. [[, b: integer): boolean
                        return a ]] .. op .. [[ b
                    end
                ]]
                local ok, err = run_checker(code)
                assert.falsy(ok)
                assert.match("left hand side of relational expression is", err)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot compare integer and " .. t .. " using " .. op, function()
                local code = [[
                    function fn(a: integer, b: ]] .. t .. [[): boolean
                        return a ]] .. op .. [[ b
                    end
                ]]
                local ok, err = run_checker(code)
                assert.falsy(ok)
                assert.match("right hand side of relational expression is", err)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean"}) do
            it("cannot compare " .. t .. " and string using " .. op, function()
                local code = [[
                    function fn(a: ]] .. t .. [[, b: string): boolean
                        return a ]] .. op .. [[ b
                    end
                ]]
                local ok, err = run_checker(code)
                assert.falsy(ok)
                assert.match("left hand side of relational expression is", err)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean"}) do
            it("cannot compare string and " .. t .. " using " .. op, function()
                local code = [[
                    function fn(a: string, b: ]] .. t .. [[): boolean
                        return a ]] .. op .. [[ b
                    end
                ]]
                local ok, err = run_checker(code)
                assert.falsy(ok)
                assert.match("right hand side of relational expression is", err)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t1 in ipairs({"{integer}", "boolean"}) do
            for _, t2 in ipairs({"{integer}", "boolean"}) do
                it("cannot compare " .. t1 .. " and " .. t2 .. " using " .. op, function()
                    local code = [[
                        function fn(a: ]] .. t1 .. [[, b: ]] .. t2 .. [[): boolean
                            return a ]] .. op .. [[ b
                        end
                    ]]
                    local ok, err = run_checker(code)
                    assert.falsy(ok)
                    if t1 ~= t2 then
                        assert.match("trying to use relational expression with", err)
                    else
                        assert.match("trying to use relational expression with two", err)
                    end
                end)
            end
        end
    end
    it("returns the type of the module with exported members", function()
        local code = [[
            a: integer = 1
            local b: float = 2
            function geta(): integer
                return a
            end
            local function foo(): nil end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local mod, err = checker.check("test", ast, code, "test.titan")
        assert.truthy(mod, err)
        assert_ast(mod, {
            _tag = "Module",
            name = "test",
            members = {
                a = { _tag = "Integer" },
                geta = { _tag = "Function" }
            }
        })
        assert.falsy(mod.members.b)
        assert.falsy(mod.members.foo)
    end)

    it("fails to load modules that do not exist", function ()
        local code = [[
            local foo = import "foo"
            local bar = import "bar.baz"
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local mod, err = checker.check("test", ast, code, "test.titan")
        assert.match("no file './foo.titan'", err)
        assert.match("no file './bar/baz.titan'", err)
    end)

    it("correctly imports modules that do exist", function ()
        local modules = {
            foo = [[
                a: integer = 1
                function foo(): nil end
            ]],
            bar = [[
                local foo = import "foo"
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.truthy(ok)
        assert.truthy(mods.foo)
        assert_ast(mods.foo.type, {
            _tag = "Module",
            name = "foo",
            members = {
                a = { _type = { _tag = "Integer" } },
                foo = { _type = { _tag = "Function" } }
            }
        })
    end)

    it("fails on circular module references", function ()
        local modules = {
            foo = [[
                local bar = import "bar"
                a: integer = nil
                function foo(): nil end
            ]],
            bar = [[
                local foo = import "foo"
            ]]
        }
        local ok, err = run_checker_modules(modules, "bar")
        assert.falsy(ok)
        assert.match("circular", err)
    end)

    it("import fails on modules with syntax errors", function ()
        local modules = {
            foo = [[
                a: integer =
                function foo(): nil end
            ]],
            bar = [[
                local foo = import "foo"
            ]]
        }
        local ok, err = run_checker_modules(modules, "bar")
        assert.falsy(ok)
        assert.match("problem loading module", err)
    end)

    it("correctly uses module variable", function ()
        local modules = {
            foo = [[
                a: integer = 1
            ]],
            bar = [[
                local foo = import "foo"
                function bar(): integer
                    foo.a = 5
                    return foo.a
                end
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.truthy(ok)
    end)

    it("uses module variable with wrong type", function ()
        local modules = {
            foo = [[
                a: integer = 1
            ]],
            bar = [[
                local foo = import "foo"
                function bar(): string
                    foo.a = "foo"
                    return foo.a
                end
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.falsy(ok)
        assert.match("expected string but found integer", err)
        assert.match("expected integer but found string", err)
    end)

    it("catches module variable initialization with wrong type", function()
        local code = {[[
            local x: integer = nil
        ]],
        [[
            x: integer = nil
        ]],
        }
        for _, c in ipairs(code) do
            local ok, err = run_checker(c)
            assert.falsy(ok)
            assert.match("expected integer but found nil", err)
        end
    end)

    it("returns the type of the module with exported members", function()
        local modules = { test = [[
            a: integer = 1
            local b: float = 2
            function geta(): integer
                return a
            end
            local function foo(): nil end
        ]] }
        local ok, err, mods = run_checker_modules(modules, "test")
        assert.truthy(ok)
        assert_ast(mods.test.type, {
            _tag = "Module",
            name = "test",
            members = {
                a = { _type = { _tag = "Integer" } },
                geta = { _type = { _tag = "Function" } }
            }
        })
        assert.falsy(mods.test.type.members.b)
        assert.falsy(mods.test.type.members.foo)
    end)

    it("fails to load modules that do not exist", function ()
        local code = [[
            local foo = import "foo"
            local bar = import "bar.baz"
        ]]
        local ok, err, ast = run_checker(code)
        assert.falsy(ok)
        assert.match("no file './foo.titan'", err)
        assert.match("no file './bar/baz.titan'", err)
    end)

    it("correctly imports modules that do exist", function ()
        local modules = {
            foo = [[
                a: integer = 1
                function foo(): nil end
            ]],
            bar = [[
                local foo = import "foo"
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.truthy(ok)
        assert.truthy(mods.foo)
        assert_ast(mods.foo.type, {
            _tag = "Module",
            name = "foo",
            members = {
                a = { _type = { _tag = "Integer" } },
                foo = { _type = { _tag = "Function" } }
            }
        })
    end)

    it("fails on circular module references", function ()
        local modules = {
            foo = [[
                local bar = import "bar"
                a: integer = nil
                function foo(): nil end
            ]],
            bar = [[
                local foo = import "foo"
            ]]
        }
        local ok, err = run_checker_modules(modules, "bar")
        assert.falsy(ok)
        assert.match("circular", err)
    end)

    it("import fails on modules with syntax errors", function ()
        local modules = {
            foo = [[
                a: integer =
                function foo(): nil end
            ]],
            bar = [[
                local foo = import "foo"
            ]]
        }
        local ok, err = run_checker_modules(modules, "bar")
        assert.falsy(ok)
        assert.match("problem loading module", err)
    end)

    it("correctly uses module variable", function ()
        local modules = {
            foo = [[
                a: integer = 1
            ]],
            bar = [[
                local foo = import "foo"
                function bar(): integer
                    foo.a = 5
                    return foo.a
                end
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.truthy(ok)
    end)

    it("uses module variable with wrong type", function ()
        local modules = {
            foo = [[
                a: integer = 1
            ]],
            bar = [[
                local foo = import "foo"
                function bar(): string
                    foo.a = "foo"
                    return foo.a
                end
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.falsy(ok)
        assert.match("expected string but found integer", err)
        assert.match("expected integer but found string", err)
    end)

    it("catches module variable initialization with wrong type", function()
        local code = {[[
            local x: integer = nil
        ]],
        [[
            x: integer = nil
        ]],
        }
        for _, c in ipairs(code) do
            local ok, err = run_checker(c)
            assert.falsy(ok)
            assert.match("expected integer but found nil", err)
        end
    end)

end)

