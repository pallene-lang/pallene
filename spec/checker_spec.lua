local checker = require 'titan-compiler.checker'
local parser = require 'titan-compiler.parser'
local types = require 'titan-compiler.types'
local driver = require 'titan-compiler.driver'
local util = require 'titan-compiler.util'

local function run_checker(code)
    driver.imported = {}
    local ast = assert(parser.parse(code))
    local t, errs = checker.check("test", ast, code, "test.titan", driver.defaultloader)
    return #errs == 0, table.concat(errs, "\n"), ast, t
end

local function run_checker_modules(modules, main)
    local imported = {}
    local loader = driver.tableloader(modules, imported)
    local _, errs = checker.checkimport(main, loader)
    return #errs == 0, table.concat(errs, "\n"), imported
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

local function assert_type_check(code)
    local ok, err = run_checker(code)
    assert.truthy(ok, err)
end

local function assert_type_error(expected, code)
    local ok, err = run_checker(code)
    assert.falsy(ok)
    assert.match(expected, err)
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
        assert.match("type 'foo' not found", err)
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
        assert.same("AstExpCast", ast[1].block.stats[2].exp._tag)
        assert.same("TypeInteger", ast[1].block.stats[2].exp.target._tag)
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
        assert.same("AstExpCast", ast[1].block.stats[2].exp._tag)
        assert.same("TypeFloat", ast[1].block.stats[2].exp.target._tag)
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
        assert.match("duplicate declaration", err)
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
            assert.match("duplicate declaration", err)
        end
    end)


    it("allows constant variable initialization", function()
        assert_type_check([[ x1 = nil ]])
        assert_type_check([[ x2 = false ]])
        assert_type_check([[ x3 = 11 ]])
        assert_type_check([[ x4 = 1.1 ]])
        assert_type_check([[ x5 = "11" ]])
        assert_type_check([[ x6 = {} ]])
        assert_type_check([[ x7 = {1, 2} ]])
        assert_type_check([[ x8 = "a" .. 10 ]])
        assert_type_check([[ x9 = 1 + 2 ]])
        assert_type_check([[ x10 = not false ]])
        assert_type_check([[ x11: integer = 10.1 ]])
    end)

    it("catches non constant variable initialization in top level", function()
        local assert_const = util.curry(assert_type_error, "must be constant")
        assert_const([[ function f(): integer return 10 end x = f() ]])
        assert_const([[ x = 10 y = x ]])
        assert_const([[ x = 10 y = -x ]])
        assert_const([[ x = 10 y = 10 + x ]])
        assert_const([[ x = 10 y = "a" .. x ]])
        assert_const([[ x = 10 y: float = x ]])
        assert_const([[ x = 10 y = {x} ]])
        assert_const([[ x = ({1})[2] ]])
    end)

    it("catches variable not declared", function()
        local code = [[
            function fn()
                local x:integer = 1
                y = 2
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("variable '%w+' not declared", err)
    end)

    it("catches array expression in indexing is not an array", function()
        local code = [[
            function fn(x: integer)
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
            function fn()
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
            function fn1()
              fn2()
            end

            function fn2()
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
            function fn()
                local arr: {integer} = { 10, 20, 30 }
                arr[1] = nil
            end
        ]]
        local ok, err = run_checker(code)
        assert.truthy(ok, err)
    end)

    it("catches named init list assigned to an array", function()
        local code = [[
            function fn(x: integer)
                local arr: {integer} = { x = 10 }
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("expected { integer } but found initlist", err)
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

    for _, op in ipairs({"and", "or"}) do
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

    for _, op in ipairs({"|", "&", "<<", ">>"}) do
        it("coerces "..op.." to integer if other side is a float", function()
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

            assert.same(types.Integer, ast[1].block.stats[3].exp.lhs._type)
            assert.same(types.Integer, ast[1].block.stats[3].exp.rhs._type)
            assert.same(types.Integer, ast[1].block.stats[3].exp._type)

            assert.same(types.Integer, ast[1].block.stats[4].exp.lhs._type)
            assert.same(types.Integer, ast[1].block.stats[4].exp.rhs._type)
            assert.same(types.Integer, ast[1].block.stats[4].exp._type)

            assert.same(types.Integer, ast[1].block.stats[5].exp.lhs._type)
            assert.same(types.Integer, ast[1].block.stats[5].exp.rhs._type)
            assert.same(types.Integer, ast[1].block.stats[5].exp._type)

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

    for _, op in ipairs({"+", "-", "*", "%", "//", "/", "^"}) do
        it("fails if one side of expression is value", function ()
            local code = [[
                function fn(): integer
                    local i: value = 1
                    local f: float = 1.5
                    local i_f = i ]] .. op .. [[ f
                    local f_i = f ]] .. op .. [[ i
                end
            ]]
            local ok, err, ast = run_checker(code)
            assert.falsy(ok)
            assert.match("is a value instead of a number", err)
        end)
    end

    it("cannot concatenate with boolean", function()
        local code = [[
            function fn()
                local s = "foo" .. true
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("cannot concatenate with boolean value", err)
    end)

    it("cannot concatenate with nil", function()
        local code = [[
            function fn()
                local s = "foo" .. nil
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("cannot concatenate with nil value", err)
    end)

    it("cannot concatenate with array", function()
        local code = [[
            function fn()
                local s = "foo" .. {}
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("cannot concatenate with { integer } value", err)
    end)

    it("cannot concatenate with type value", function()
        local code = [[
            function fn()
                local v: value = "bar"
                local s = "foo" .. v
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("cannot concatenate with value", err)
    end)

    it("can concatenate with integer and float", function()
        local code = [[
            function fn()
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

    for _, op in ipairs({"and", "or"}) do
        for _, t1 in ipairs({"{integer}", "integer", "string"}) do
            for _, t2 in ipairs({"integer", "integer", "string"}) do
                if t1 ~= t2 then
                    it("cannot evaluate " .. t1 .. " and " .. t2 .. " using " .. op, function()
                        local code = [[
                            function fn(a: ]] .. t1 .. [[, b: ]] .. t2 .. [[): boolean
                                return a ]] .. op .. [[ b
                            end
                        ]]
                        local ok, err = run_checker(code)
                        assert.falsy(ok)
                        assert.match("left hand side of logical expression is a", err)
                    end)
                end
            end
        end
    end

    for _, op in ipairs({"|", "&", "<<", ">>"}) do
        it("can use bitwise operators with integers using " .. op, function()
            local code = [[
                function fn(i1: integer, i2: integer): integer
                    return i1 ]] .. op .. [[ i2
                end
            ]]
            local ok, err = run_checker(code)
            assert.truthy(ok)
        end)
    end

    for _, op in ipairs({"|", "&", "<<", ">>"}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot use bitwise operator " .. op .. " when left hand side is not integer", function()
                local code = [[
                    function fn(a: ]] .. t .. [[, b: integer): boolean
                        return a ]] .. op .. [[ b
                    end
                ]]
                local ok, err = run_checker(code)
                assert.falsy(ok)
                assert.match("left hand side of arithmetic expression is a", err)
            end)
        end
    end

    for _, op in ipairs({"|", "&", "<<", ">>"}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot use bitwise operator " .. op .. " when right hand side is not integer", function()
                local code = [[
                    function fn(a: integer, b: ]] .. t .. [[): boolean
                        return a ]] .. op .. [[ b
                    end
                ]]
                local ok, err = run_checker(code)
                assert.falsy(ok)
                assert.match("right hand side of arithmetic expression is a", err)
            end)
        end
    end

    for _, t in ipairs({"{integer}", "boolean", "float", "integer", "nil", "string"}) do
        it("can explicitly cast from value to " .. t, function()
            local code = [[
                function fn(a: value): ]] .. t .. [[
                    return a as ]] .. t .. [[
                end
            ]]
            local ok, err = run_checker(code)
            assert.truthy(ok)
        end)
    end

    for _, t in ipairs({"{integer}", "boolean", "float", "integer", "nil", "string"}) do
        it("can explicitly cast from " .. t .. "to value", function()
            local code = [[
                function fn(a: ]] .. t .. [[): value
                    return a as value
                end
            ]]
            local ok, err = run_checker(code)
            assert.truthy(ok)
        end)
    end

    for _, t in ipairs({"boolean", "float", "integer", "nil", "string"}) do
        it("cannot explicitly cast from " .. t .. " to {integer}", function()
            local code = [[
                function fn(a: ]] .. t .. [[): {integer}
                    return a as {integer}
                end
            ]]
            local ok, err = run_checker(code)
            assert.falsy(ok)
            assert.match("cannot cast", err)
        end)
    end

    for _, t in ipairs({"{integer}", "boolean", "integer", "nil", "string"}) do
        it("cannot explicitly cast from " .. t .. " to float", function()
            local code = [[
                function fn(a: ]] .. t .. [[): float
                    return a as float
                end
            ]]
            local ok, err = run_checker(code)
            assert.falsy(ok)
            assert.match("cannot cast", err)
        end)
    end

    for _, t in ipairs({"{integer}", "boolean", "nil", "string"}) do
        it("cannot explicitly cast from " .. t .. " to integer", function()
            local code = [[
                function fn(a: ]] .. t .. [[): integer
                    return a as integer
                end
            ]]
            local ok, err = run_checker(code)
            assert.falsy(ok)
            assert.match("cannot cast", err)
        end)
    end

    for _, t in ipairs({"{integer}", "boolean", "float", "integer", "string"}) do
        it("cannot explicitly cast from " .. t .. " to nil", function()
            local code = [[
                function fn(a: ]] .. t .. [[): nil
                    return a as nil
                end
            ]]
            local ok, err = run_checker(code)
            assert.falsy(ok)
            assert.match("cannot cast", err)
        end)
    end

    for _, t in ipairs({"{integer}", "boolean", "nil"}) do
        it("cannot explicitly cast from " .. t .. " to string", function()
            local code = [[
                function fn(a: ]] .. t .. [[): string
                    return a as string
                end
            ]]
            local ok, err = run_checker(code)
            assert.falsy(ok)
            assert.match("cannot cast", err)
        end)
    end

    it("returns the type of the module with exported members", function()
        local modules = { test = [[
            a: integer = 1
            local b: float = 2
            function geta(): integer
                return a
            end
            local function foo() end
        ]] }
        local ok, err, mods = run_checker_modules(modules, "test")
        assert.truthy(ok)
        assert_ast(mods.test.type, {
            _tag = "Module",
            name = "test",
            members = {
                a = { _tag = "TypeInteger" },
                geta = { _tag = "TypeFunction" }
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
        assert.match("module 'foo' not found", err)
        assert.match("module 'bar.baz' not found", err)
    end)

    it("correctly imports modules that do exist", function ()
        local modules = {
            foo = [[
                a: integer = 1
                function foo() end
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
                a = { _tag = "TypeInteger" },
                foo = { _tag = "TypeFunction" }
            }
        })
    end)

    it("fails on circular module references", function ()
        local modules = {
            foo = [[
                local bar = import "bar"
                a: integer = nil
                function foo() end
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
                function foo() end
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

    it("catches use of function as first-class value", function ()
        local code = [[
            function foo(): integer
                return foo
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("access a function", err)
    end)

    it("catches assignment to function", function ()
        local code = [[
            function foo(): integer
                foo = 2
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("assign to a function", err)
    end)

    it("catches use of external function as first-class value", function ()
        local modules = {
            foo = [[
                a: integer = 1
                function foo()
                end
            ]],
            bar = [[
                local foo = import "foo"
                function bar(): integer
                    return foo.foo
                end
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.falsy(ok)
        assert.match("access a function", err)
    end)

    it("catches assignment to external function", function ()
        local modules = {
            foo = [[
                a: integer = 1
                function foo()
                end
            ]],
            bar = [[
                local foo = import "foo"
                function bar(): integer
                    foo.foo = 2
                end
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.falsy(ok)
        assert.match("assign to a function", err)
    end)

    it("catches use of module as first-class value", function ()
        local modules = {
            foo = [[
                a: integer = 1
            ]],
            bar = [[
                local foo = import "foo"
                function bar(): integer
                    return foo
                end
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.falsy(ok)
        assert.match("access module", err)
    end)

    it("catches assignment to module", function ()
        local modules = {
            foo = [[
                a: integer = 1
            ]],
            bar = [[
                local foo = import "foo"
                function bar(): integer
                    foo = 2
                end
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.falsy(ok)
        assert.match("assign to a module", err)
    end)

    it("catches call of external non-function", function ()
        local modules = {
            foo = [[
                a: integer = 1
            ]],
            bar = [[
                local foo = import "foo"
                function bar(): integer
                    return foo.a()
                end
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.falsy(ok)
        assert.match("'foo.a' is not a function", err)
    end)

    it("catches call if non-function function", function ()
        local code = [[
            local a = 2
            function foo(): integer
                return a()
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match("'a' is not a function", err)
    end)

    it("correctly uses module function", function ()
        local modules = {
            foo = [[
                function a(): integer
                    return 42
                end
            ]],
            bar = [[
                local foo = import "foo"
                function bar(): integer
                    return foo.a()
                end
            ]]
        }
        local ok, err, mods = run_checker_modules(modules, "bar")
        assert.truthy(ok)
    end)

    it("functions cannot have two parameters with the same name", function()
        local code = [[
            function f(a: integer, a: integer)
            end
        ]]
        local ok, err = run_checker(code)
        assert.falsy(ok)
        assert.match('duplicate parameter', err)
    end)
end)

describe("Titan typecheck of records", function()
    it("typechecks record declarations", function()
        assert_type_check([[
            record Point
                x: float
                y: float
            end
        ]])
    end)

    it("detects type errors inside record declarations", function()
        assert_type_error("type 'notfound' not found", [[
            record Point
                x: notfound
            end
        ]])
    end)

    it("doesn't typecheck recursive record declarations", function()
        -- TODO: it should accept recursive types when we have optional types
        assert_type_error("type 'List' not found", [[
            record List
                l: List
            end
        ]])
    end)

    it("typechecks record as argument/return", function()
        assert_type_check([[
            record Point x: float; y:float end

            function f(p: Point): Point
                return p
            end
        ]])
    end)

    it("typechecks record constructors", function()
        assert_type_check([[
            record Point x: float; y:float end

            p = Point.new(1, 2)
        ]])
    end)

    it("doesn't typecheck invalid dot operation in record", function()
        assert_type_error("invalid record member 'nope'", [[
            record Point x: float; y:float end

            p = Point.nope(1, 2)
        ]])
    end)

    it("doesn't typecheck constructor call of non records", function()
        pending("typechecker thinks 'integer' is an undeclared variable; " ..
                "basic types should be added to the symbol table.")

        assert_type_error("invalid access to type 'integer'", [[
            p = integer.new(10)
        ]])
    end)

    local function wrap_record(code)
        return [[
            record Point x: float; y:float end

            function f(p: Point): float
                ]].. code ..[[
            end
        ]]
    end

    it("doesn't typecheck constructor calls with wrong arguments", function()
        assert_type_error("expected float but found string",
                          wrap_record[[ p = Point.new("a", "b") ]])
        assert_type_error("Point.new called with 1 arguments but expects 2",
                          wrap_record[[ p = Point.new(1) ]])
        assert_type_error("Point.new called with 3 arguments but expects 2",
                          wrap_record[[ p = Point.new(1, 2, 3) ]])
    end)

    it("typechecks record read/write", function()
        assert_type_check(wrap_record[[
            local x: float = 10
            p.x = x
            return p.y
        ]])
    end)

    it("doesn't typecheck read/write to non existent fields", function()
        local function assert_non_existent(code)
            assert_type_error("field 'nope' not found in record 'Point'",
                              wrap_record(code))
        end
        assert_non_existent([[ p.nope = 10 ]])
        assert_non_existent([[ return p.nope ]])
    end)

    it("doesn't typecheck read/write with invalid types", function()
        assert_type_error("expected float but found Point",
                          wrap_record[[ p.x = p ]])
        assert_type_error("expected Point but found float",
                          wrap_record[[ local p: Point = p.x ]])
    end)
end)

