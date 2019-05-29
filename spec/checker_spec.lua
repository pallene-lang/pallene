local ast = require 'pallene.ast'
local driver = require 'pallene.driver'
local types = require 'pallene.types'
local util = require 'pallene.util'

local function run_checker(code)
    assert(util.set_file_contents("test.pallene", code))
    local prog_ast, errs = driver.test_ast("checker", "test.pallene")
    return prog_ast, table.concat(errs, "\n")
end

local function assert_type_check(code)
    local prog_ast, errs = run_checker(code)
    assert.truthy(prog_ast, errs)
end

local function assert_type_error(expected, code)
    local prog_ast, errs = run_checker(code)
    assert.falsy(prog_ast)
    assert.match(expected, errs)
end

describe("Pallene type checker", function()

    teardown(function()
        os.remove("test.pallene")
    end)

    it("detects when a non-type is used in a type variable", function()
        local prog_ast, errs = run_checker([[
            local foo: integer = 10
            local bar: foo = 11
        ]])
        assert.falsy(prog_ast)
        assert.match("'foo' isn't a type", errs)
    end)

    it("detects when a non-value is used in a value variable", function()
        local prog_ast, errs = run_checker([[
            record Point
                x: integer
                y: integer
            end
            local bar: integer = Point
        ]])
        assert.falsy(prog_ast)
        assert.match("'Point' isn't a value", errs)
    end)

    it("for loop iteration variables don't shadow var limit and step", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer): integer
                local i: string = "asdfg"
                for i = 1, #i do
                    x = x + i
                end
                return x
            end
        ]])
        assert(prog_ast, errs)
    end)

    it("allows constant variable initialization", function()
        assert_type_check([[ local x1 = nil ]])
        assert_type_check([[ local x2 = false ]])
        assert_type_check([[ local x3 = 11 ]])
        assert_type_check([[ local x4 = 1.1 ]])
        assert_type_check([[ local x5 = "11" ]])
        assert_type_check([[ local x6: {integer} = {} ]])
        assert_type_check([[ local x7: {integer} = {1, 2} ]])
        assert_type_check([[ local x8 = "a" .. 10 ]])
        assert_type_check([[ local x9 = 1 + 2 ]])
        assert_type_check([[ local x10 = not false ]])
        assert_type_check([[ local x11 = 10.1 ]])
    end)

    it("allows non constant variable initialization", function()
        assert_type_check([[
            function f(): integer
                return 10
            end
            local x = f() ]])
        assert_type_check([[
            local x = 10
            local y = x ]])
        assert_type_check([[
            local x = 10
            local y = -x ]])
        assert_type_check([[
            local x = 10
            local y = 10 + x ]])
        assert_type_check([[
            local x = "b"
            local y = "a" .. x ]])
        assert_type_check([[
            local x = 10
            local y: integer = x ]])
        assert_type_check([[
            local x = 10
            local y: {integer} = {x} ]])
    end)

    it("catches array expression in indexing is not an array", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer)
                x[1] = 2
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("array expression in indexing is not an array", errs)
    end)

    it("accepts correct use of length operator", function()
        local prog_ast, errs = run_checker([[
            function fn(x: {integer}): integer
                return #x
            end
        ]])
        assert(prog_ast, errs)
    end)

    it("catches wrong use of length operator", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer): integer
                return #x
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("trying to take the length", errs)
    end)

    it("catches wrong use of unary minus", function()
        local prog_ast, errs = run_checker([[
            function fn(x: boolean): boolean
                return -x
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("trying to negate a", errs)
    end)

    it("catches wrong use of bitwise not", function()
        local prog_ast, errs = run_checker([[
            function fn(x: boolean): boolean
                return ~x
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("trying to bitwise negate a", errs)
    end)

    it("catches wrong use of boolean not", function()
        local prog_ast, errs = run_checker([[
            function fn(): boolean
                return not nil
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("trying to boolean negate a nil", errs)
    end)

    it("catches mismatching types in locals", function()
        local prog_ast, errs = run_checker([[
            function fn()
                local i: integer = 1
                local s: string = "foo"
                s = i
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("integer is not assignable to string", errs)
    end)

    it("function can call another function", function()
        local prog_ast, errs = run_checker([[
            function fn1()
            end

            function fn2()
              fn1()
            end
        ]])
        assert(prog_ast, errs)
    end)

    it("catches mismatching types in arguments", function()
        local prog_ast, errs = run_checker([[
            function fn(i: integer, s: string): integer
                s = i
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("integer is not assignable to string", errs)
    end)

    it("can create empty array (with type annotation)", function()
        local prog_ast, errs = run_checker([[
            local xs: {integer} = {}
        ]])
        assert(prog_ast, errs)
    end)

    it("can create non-empty array (with type annotation)", function()
        local prog_ast, errs = run_checker([[
            local xs: {integer} = {10, 20, 30}
        ]])
        assert(prog_ast, errs)
    end)

    it("can create array of array (with type annotation)", function()
        local prog_ast, errs = run_checker([[
            local xs: {{integer}} = {{10,20}, {30,40}}
        ]])
        assert(prog_ast, errs)
    end)

    it("forbids empty array (without type annotation)", function()
        local prog_ast, errs = run_checker([[
            local xs = {}
        ]])
        assert.falsy(prog_ast)
        assert.matches("missing type hint for array or record initializer", errs)
    end)

    it("forbids non-empty array (without type annotation)", function()
        local prog_ast, errs = run_checker([[
            local xs = {10, 20, 30}
        ]])
        assert.falsy(prog_ast)
        assert.matches("missing type hint for array or record initializer", errs)
    end)

    it("forbids array initializers with a table part", function()
        local prog_ast, errs = run_checker([[
            local xs: {integer} = {10, 20, 30, x=17}
        ]])
        assert.falsy(prog_ast)
        assert.matches("named field x in array initializer", errs)
    end)

    it("forbids wrong type in array initializer", function()
        local prog_ast, errs = run_checker([[
            local xs: {integer} = {10, "hello"}
        ]])
        assert.falsy(prog_ast)
        assert.matches("expected integer but found string", errs)
    end)

    it("can create record (with type annotation)", function()
        local prog_ast, errs = run_checker([[
            record Point
                x: float
                y: float
            end
            local p: Point = { x = 10.0, y = 20.0 }
        ]])
        assert(prog_ast, errs)
    end)

    it("can create array of record (with type annotation)", function()
        local prog_ast, errs = run_checker([[
            record Point
                x: float
                y: float
            end
            local ps: {Point} = {
                { x = 10.0, y = 20.0 },
                { x = 30.0, y = 40.0 },
            }
        ]])
        assert(prog_ast, errs)
    end)

    it("can create record of record (with type annotation)", function()
        local prog_ast, errs = run_checker([[
            record Point
                x: float
                y: float
            end
            record Circle
                center: Point
                radius: float
            end
            local c: Circle = { center = { x = 10.0, y = 20.0 }, radius = 5.0 }
        ]])
        assert(prog_ast, errs)
    end)

    it("forbids record creation (without type annotation)", function()
        local prog_ast, errs = run_checker([[
            record Point
                x: float
                y: float
            end
            local p = { x = 10.0, y = 20.0 }
        ]])
        assert.falsy(prog_ast)
        assert.matches("missing type hint for array or record initializer", errs)
    end)

    it("forbids wrong type in record initializer", function()
        local prog_ast, errs = run_checker([[
            record Point
                x: float
                y: float
            end
            local p: Point = { x = 10.0, y = "hello" }
        ]])
        assert.falsy(prog_ast)
        assert.matches("expected float but found string", errs)
    end)

    it("forbids wrong field name in record initializer", function()
        local prog_ast, errs = run_checker([[
            record Point
                x: float
                y: float
            end
            local p: Point = { x = 10.0, y = 20.0, z = 30.0 }
        ]])
        assert.falsy(prog_ast)
        assert.matches("invalid field z in record initializer for Point", errs)
    end)

    it("forbids array part in record initializer", function()
        local prog_ast, errs = run_checker([[
            record Point
                x: float
                y: float
            end
            local p: Point = { x = 10.0, y = 20.0, 30.0 }
        ]])
        assert.falsy(prog_ast)
        assert.matches("record initializer has array part", errs)
    end)

    it("forbids initializing a record field twice", function()
        local prog_ast, errs = run_checker([[
            record Point
                x: float
                y: float
            end
            local p: Point = { x = 10.0, x = 11.0, y = 20.0 }
        ]])
        assert.falsy(prog_ast)
        assert.matches("duplicate field x in record initializer", errs)
    end)

    it("forbids missing fields in record initializer", function()
        local prog_ast, errs = run_checker([[
            record Point
                x: float
            end
            local p: Point = { }
        ]])
        assert.falsy(prog_ast)
        assert.matches("required field x is missing", errs)
    end)

    it("forbids type hints that are not array or records", function()
        local prog_ast, errs = run_checker([[
            local p: string = { 10, 20, 30 }
        ]])
        assert.falsy(prog_ast)
        assert.matches("type hint for array or record initializer is not an array or record type", errs)
    end)

    it("forbids array of nil", function()
        local prog_ast, errs = run_checker([[
            local xs: {nil} = {}
        ]])
        assert.falsy(prog_ast)
        assert.matches(
            "array of nil is not allowed",
            errs, nil, true)
    end)

    it("type-checks numeric 'for' (integer, implicit step)", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer): integer
                for i:integer = 1, 10 do
                    x = x + 1
                end
                return x
            end
        ]])
        assert(prog_ast, errs)
    end)

    it("type-checks numeric 'for' (integer, explicit step)", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer): integer
                for i:integer = 1, 10, 2 do
                    x = x + i
                end
                return x
            end
        ]])
        assert(prog_ast, errs)
    end)

    it("type-checks numeric 'for' (float, implicit step)", function()
        local prog_ast, errs = run_checker([[
            function fn(x: float): float
                for i:float = 1.0, 10.0 do
                    x = x + i
                end
                return x
            end
        ]])
        assert(prog_ast, errs)
    end)

    it("type-checks numeric 'for' (float, explicit step)", function()
        local prog_ast, errs = run_checker([[
            function fn(x: float): float
                for i:float = 1.0, 10.0, 2.0 do
                    x = x + i
                end
                return x
            end
        ]])
        assert(prog_ast, errs)
    end)

    it("type-checks 'while'", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer): integer
                local i: integer = 15
                while x < 100 do
                    x = x + i
                end
                return x
            end
        ]])
        assert(prog_ast, errs)
    end)

    it("requires while statement conditions to be boolean", function()
        local prog_ast, errs = run_checker([[
            function fn(x:integer): integer
                while x do
                    return 10
                end
                return 20
            end
        ]])
        assert.falsy(prog_ast)
        assert.matches("types in while statement condition do not match, expected boolean but found integer", errs)
    end)

    it("type-checks 'repeat'", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer): integer
                local i: integer = 15
                repeat
                    x = x + i
                until x >= 100
                return x
            end
        ]])
        assert(prog_ast, errs)
    end)

     it("requires repeat statement conditions to be boolean", function()
        local prog_ast, errs = run_checker([[
            function fn(x:integer): integer
                repeat
                    return 10
                until x
                return 20
            end
        ]])
        assert.falsy(prog_ast)
        assert.matches("types in repeat statement condition do not match, expected boolean but found integer", errs)
    end)

    it("type-checks 'if'", function()
        local prog_ast, errs = run_checker([[
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
        ]])
        assert(prog_ast, errs)
    end)

    it("requires if statement conditions to be boolean", function()
        local prog_ast, errs = run_checker([[
            function fn(x:integer): integer
                if x then
                    return 10
                else
                    return 20
                end
            end
        ]])
        assert.falsy(prog_ast)
        assert.matches("types in if statement condition do not match, expected boolean but found integer", errs)
    end)

    it("checks code inside the 'while' block", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer): integer
                local i: integer = 15
                while i > 0 do
                    local s: string = i
                end
                return x
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("integer is not assignable to string", errs)
    end)

    it("ensures numeric 'for' variable has number type (with annotation)", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer, s: string): integer
                for i: string = 1, 10, 2 do
                    x = x + i
                end
                return x
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("control variable", errs)
    end)

    it("ensures numeric 'for' variable has number type (without annotation)", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer, s: string): integer
                for i = s, 10, 2 do
                    x = x + i
                end
                return x
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("control variable", errs)
    end)


    it("catches 'for' errors in the start expression", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer, s: string): integer
                for i:integer = s, 10, 2 do
                    x = x + i
                end
                return x
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("numeric for loop initializer", errs)
    end)


    it("catches 'for' errors in the limit expression", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer, s: string): integer
                for i = 1, s, 2 do
                    x = x + i
                end
                return x
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("numeric for loop limit", errs)
    end)

    it("catches 'for' errors in the step expression", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer, s: string): integer
                for i = 1, 10, s do
                    x = x + i
                end
                return x
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("numeric for loop step", errs)
    end)

    it("detects too many return values", function()
        local prog_ast, errs = run_checker([[
            function f(): ()
                return 1
            end
        ]])
        assert.falsy(prog_ast)
        assert.match(
            "returning 1 value(s) but function expects 0", errs,
            nil, true)
    end)

    it("detects too few return values", function()
        local prog_ast, errs = run_checker([[
            function f(): integer
                return
            end
        ]])
        assert.falsy(prog_ast)
        assert.match(
            "returning 0 value(s) but function expects 1", errs,
            nil, true)
    end)

    it("accepts functions that return 0 values", function()
        local prog_ast, errs = run_checker([[
            function f(): ()
                return
            end
        ]])
        assert(prog_ast, errs)
    end)

    it("accepts functions that return 1 value", function()
        local prog_ast, errs = run_checker([[
            function f(): integer
                return 17
            end
        ]])
        assert(prog_ast, errs)
    end)

    it("detects when a function returns the wrong type", function()
        local prog_ast, errs = run_checker([[
            function fn(): integer
                return "hello"
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("return statement: string is not assignable to intege", errs)
    end)

    it("detects missing return statements", function()
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
            local prog_ast, errs = run_checker(c)
            assert.falsy(prog_ast)
            assert.match("control reaches end of function with non%-empty return type", errs)
        end
    end)

    it("rejects void functions in expression contexts", function()
        local prog_ast, errs = run_checker([[
            local function f(): ()
            end

            local function g(): integer
                return 1 + f()
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("void instead of a number", errs)
    end)

    it("detects attempts to call non-functions", function()
        local prog_ast, errs = run_checker([[
            function fn(): integer
                local i: integer = 0
                i()
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("attempting to call a integer value" , errs)
    end)

    it("detects wrong number of arguments to functions", function()
        local prog_ast, errs = run_checker([[
            function f(x: integer, y: integer): integer
                return x + y
            end

            function g(): integer
                return f(1)
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("function expects 2 argument(s) but received 1", errs,
            nil, true)
    end)

    it("detects wrong types of arguments to functions", function()
        local prog_ast, errs = run_checker([[
            function f(x: integer, y: integer): integer
                return x + y
            end

            function g(): integer
                return f(1.0, 2.0)
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("float is not assignable to integer", errs,nil, true)
    end)

    for _, op in ipairs({"+", "-", "*", "%", "//"}) do
        it("coerces "..op.." to float if any side is a float", function()
            local prog_ast, errs = run_checker([[
                function fn()
                    local i: integer = 1
                    local f: float = 1.5
                    local i_f = i ]] .. op .. [[ f
                    local f_i = f ]] .. op .. [[ i
                    local f_f = f ]] .. op .. [[ f
                    local i_i = i ]] .. op .. [[ i
                end
            ]])
            assert(prog_ast, errs)

            assert.same(types.T.Float(), prog_ast[1].block.stats[3].exp.lhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[3].exp.rhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[3].exp._type)

            assert.same(types.T.Float(), prog_ast[1].block.stats[4].exp.lhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[4].exp.rhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[4].exp._type)

            assert.same(types.T.Float(), prog_ast[1].block.stats[5].exp.lhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[5].exp.rhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[5].exp._type)

            assert.same(types.T.Integer(), prog_ast[1].block.stats[6].exp.lhs._type)
            assert.same(types.T.Integer(), prog_ast[1].block.stats[6].exp.rhs._type)
            assert.same(types.T.Integer(), prog_ast[1].block.stats[6].exp._type)
        end)
    end

    for _, op in ipairs({"/", "^"}) do
        it("always coerces "..op.." to float", function()
            local prog_ast, errs = run_checker([[
                function fn()
                    local i: integer = 1
                    local f: float = 1.5
                    local i_f = i ]] .. op .. [[ f
                    local f_i = f ]] .. op .. [[ i
                    local f_f = f ]] .. op .. [[ f
                    local i_i = i ]] .. op .. [[ i
                end
            ]])
            assert(prog_ast, errs)

            assert.same(types.T.Float(), prog_ast[1].block.stats[3].exp.lhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[3].exp.rhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[3].exp._type)

            assert.same(types.T.Float(), prog_ast[1].block.stats[4].exp.lhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[4].exp.rhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[4].exp._type)

            assert.same(types.T.Float(), prog_ast[1].block.stats[5].exp.lhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[5].exp.rhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[5].exp._type)

            assert.same(types.T.Float(), prog_ast[1].block.stats[6].exp.lhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[6].exp.rhs._type)
            assert.same(types.T.Float(), prog_ast[1].block.stats[6].exp._type)
        end)
    end

    it("cannot concatenate with boolean", function()
        local prog_ast, errs = run_checker([[
            function fn()
                local s = "foo" .. true
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("cannot concatenate with boolean value", errs)
    end)

    it("cannot concatenate with nil", function()
        local prog_ast, errs = run_checker([[
            function fn()
                local s = "foo" .. nil
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("cannot concatenate with nil value", errs)
    end)

    it("cannot concatenate with array", function()
        local prog_ast, errs = run_checker([[
            function fn()
                local xs: {integer} = {}
                local s = "foo" .. xs
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("cannot concatenate with { integer } value", errs)
    end)

    it("can concatenate with integer and float", function()
        local prog_ast, errs = run_checker([[
            function fn()
                local s = 1 .. 2.5
            end
        ]])
        assert(prog_ast, errs)
    end)

    for _, op in ipairs({"==", "~="}) do
        it("can compare arrays of same type using " .. op, function()
            local prog_ast, errs = run_checker([[
                function fn(a1: {integer}, a2: {integer}): boolean
                    return a1 ]] .. op .. [[ a2
                end
            ]])
            assert(prog_ast, errs)
        end)
    end

    for _, op in ipairs({"==", "~="}) do
        it("can compare booleans using " .. op, function()
            local prog_ast, errs = run_checker([[
                function fn(b1: string, b2: string): boolean
                    return b1 ]] .. op .. [[ b2
                end
            ]])
            assert(prog_ast, errs)
        end)
    end

    for _, op in ipairs({"==", "~=", "<", ">", "<=", ">="}) do
        it("can compare floats using " .. op, function()
            local prog_ast, errs = run_checker([[
                function fn(f1: string, f2: string): boolean
                    return f1 ]] .. op .. [[ f2
                end
            ]])
            assert(prog_ast, errs)
        end)
    end

    for _, op in ipairs({"==", "~=", "<", ">", "<=", ">="}) do
        it("can compare integers using " .. op, function()
            local prog_ast, errs = run_checker([[
                function fn(i1: string, i2: string): boolean
                    return i1 ]] .. op .. [[ i2
                end
            ]])
            assert(prog_ast, errs)
        end)
    end

    for _, op in ipairs({"==", "~=", "<", ">", "<=", ">="}) do
        it("can compare integers and floats using " .. op, function()
            local prog_ast, errs = run_checker([[
                function fn(i: integer, f: float): boolean
                    return i ]] .. op .. [[ f
                end
            ]])
            assert.falsy(prog_ast)
            assert.match("comparisons between float and integers are not yet implemented", errs)
        end)
    end

    for _, op in ipairs({"==", "~=", "<", ">", "<=", ">="}) do
        it("can compare strings using " .. op, function()
            local prog_ast, errs = run_checker([[
                function fn(s1: string, s2: string): boolean
                    return s1 ]] .. op .. [[ s2
                end
            ]])
            assert(prog_ast, errs)
        end)
    end

    for _, op in ipairs({"==", "~="}) do
        it("cannot compare arrays of different types using " .. op, function()
            local prog_ast, errs = run_checker([[
                function fn(a1: {integer}, a2: {float}): boolean
                    return a1 ]] .. op .. [[ a2
                end
            ]])
            assert.falsy(prog_ast)
            assert.match("cannot compare .* and .* with .*", errs)
        end)
    end

    for _, op in ipairs({"==", "~="}) do
        for _, t1 in ipairs({"{integer}", "boolean", "float", "string"}) do
            for _, t2 in ipairs({"{integer}", "boolean", "float", "string"}) do
                if t1 ~= t2 then
                    it("cannot compare " .. t1 .. " and " .. t2 .. " using " .. op, function()
                        local prog_ast, errs = run_checker([[
                            function fn(a: ]] .. t1 .. [[, b: ]] .. t2 .. [[): boolean
                                return a ]] .. op .. [[ b
                            end
                        ]])
                        assert.falsy(prog_ast)
                        assert.match("cannot compare .* and .* with .*", errs)
                    end)
                end
            end
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot compare " .. t .. " and float using " .. op, function()
                local prog_ast, errs = run_checker([[
                    function fn(a: ]] .. t .. [[, b: float): boolean
                        return a ]] .. op .. [[ b
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("cannot compare .* and .* with .*", errs)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot compare float and " .. t .. " using " .. op, function()
                local prog_ast, errs = run_checker([[
                    function fn(a: float, b: ]] .. t .. [[): boolean
                        return a ]] .. op .. [[ b
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("cannot compare .* and .* with .*", errs)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot compare " .. t .. " and integer using " .. op, function()
                local prog_ast, errs = run_checker([[
                    function fn(a: ]] .. t .. [[, b: integer): boolean
                        return a ]] .. op .. [[ b
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("cannot compare .* and .* with .*", errs)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot compare integer and " .. t .. " using " .. op, function()
                local prog_ast, errs = run_checker([[
                    function fn(a: integer, b: ]] .. t .. [[): boolean
                        return a ]] .. op .. [[ b
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("cannot compare .* and .* with .*", errs)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean"}) do
            it("cannot compare " .. t .. " and string using " .. op, function()
                local prog_ast, errs = run_checker([[
                    function fn(a: ]] .. t .. [[, b: string): boolean
                        return a ]] .. op .. [[ b
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("cannot compare .* and .* with .*", errs)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t in ipairs({"{integer}", "boolean"}) do
            it("cannot compare string and " .. t .. " using " .. op, function()
                local prog_ast, errs = run_checker([[
                    function fn(a: string, b: ]] .. t .. [[): boolean
                        return a ]] .. op .. [[ b
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("cannot compare .* and .* with .*", errs)
            end)
        end
    end

    for _, op in ipairs({"<", ">", "<=", ">="}) do
        for _, t1 in ipairs({"{integer}", "boolean"}) do
            for _, t2 in ipairs({"{integer}", "boolean"}) do
                it("cannot compare " .. t1 .. " and " .. t2 .. " using " .. op, function()
                    local prog_ast, errs = run_checker([[
                        function fn(a: ]] .. t1 .. [[, b: ]] .. t2 .. [[): boolean
                            return a ]] .. op .. [[ b
                        end
                    ]])
                    assert.falsy(prog_ast)
                    assert.match("cannot compare .* and .* with .*", errs)
                end)
            end
        end
    end

    for _, op in ipairs({"and", "or"}) do
        for _, t1 in ipairs({"{integer}", "integer", "string"}) do
            it("cannot have " .. t1 .. " as left operand of " .. op, function()
                local prog_ast, errs = run_checker([[
                    function fn(x: ]] .. t1 .. [[): boolean
                        return x ]] .. op .. [[ true
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("left hand side of logical expression is a", errs)
            end)
            it("cannot have " .. t1 .. " as right operand of " .. op, function()
                local prog_ast, errs = run_checker([[
                    function fn(x: ]] .. t1 .. [[): boolean
                        return true ]] .. op .. [[ x
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("right hand side of logical expression is a", errs)
            end)

        end
    end

    for _, op in ipairs({"|", "&", "<<", ">>"}) do
        it("can use bitwise operators with integers using " .. op, function()
            local prog_ast, errs = run_checker([[
                function fn(i1: integer, i2: integer): integer
                    return i1 ]] .. op .. [[ i2
                end
            ]])
            assert(prog_ast, errs)
        end)
    end

    for _, op in ipairs({"|", "&", "<<", ">>"}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot use bitwise operator " .. op .. " when left hand side is not integer", function()
                local prog_ast, errs = run_checker([[
                    function fn(a: ]] .. t .. [[, b: integer): boolean
                        return a ]] .. op .. [[ b
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("left hand side of arithmetic expression is a", errs)
            end)
        end
    end

    for _, op in ipairs({"|", "&", "<<", ">>"}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot use bitwise operator " .. op .. " when right hand side is not integer", function()
                local prog_ast, errs = run_checker([[
                    function fn(a: integer, b: ]] .. t .. [[): boolean
                        return a ]] .. op .. [[ b
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("right hand side of arithmetic expression is a", errs)
            end)
        end
    end

    for _, op in ipairs({"+", "-", "*", "//", "/", "^"}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot use arithmetic operator " .. op .. " when left hand side is not a  number", function()
                local prog_ast, errs = run_checker([[
                    function fn(a: ]] .. t .. [[, b: float): float
                        return a ]] .. op .. [[ b
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("left hand side of arithmetic expression is a", errs)
            end)
        end
    end

    for _, op in ipairs({"+", "-", "*", "//", "/", "^"}) do
        for _, t in ipairs({"{integer}", "boolean", "string"}) do
            it("cannot use arithmetic operator " .. op .. " when right hand side is not integer", function()
                local prog_ast, errs = run_checker([[
                    function fn(a: float, b: ]] .. t .. [[): float
                        return a ]] .. op .. [[ b
                    end
                ]])
                assert.falsy(prog_ast)
                assert.match("right hand side of arithmetic expression is a", errs)
            end)
        end
    end

    for _, t in ipairs({"boolean", "float", "integer", "nil", "string"}) do
        it("cannot explicitly cast from " .. t .. " to {integer}", function()
            local prog_ast, errs = run_checker([[
                function fn(a: ]] .. t .. [[): {integer}
                    return a as {integer}
                end
            ]])
            assert.falsy(prog_ast)
            assert.match("cannot cast", errs)
        end)
    end

    for _, t in ipairs({"{integer}", "boolean", "nil", "string"}) do
        it("cannot explicitly cast from " .. t .. " to float", function()
            local prog_ast, errs = run_checker([[
                function fn(a: ]] .. t .. [[): float
                    return a as float
                end
            ]])
            assert.falsy(prog_ast)
            assert.match("cannot cast", errs)
        end)
    end

    for _, t in ipairs({"{integer}", "boolean", "nil", "string"}) do
        it("cannot explicitly cast from " .. t .. " to integer", function()
            local prog_ast, errs = run_checker([[
                function fn(a: ]] .. t .. [[): integer
                    return a as integer
                end
            ]])
            assert.falsy(prog_ast)
            assert.match("cannot cast", errs)
        end)
    end

    for _, t in ipairs({"{integer}", "boolean", "float", "integer", "string"}) do
        it("cannot explicitly cast from " .. t .. " to nil", function()
            local prog_ast, errs = run_checker([[
                function fn(a: ]] .. t .. [[): nil
                    return a as nil
                end
            ]])
            assert.falsy(prog_ast)
            assert.match("cannot cast", errs)
        end)
    end

    for _, t in ipairs({"{integer}", "boolean", "nil"}) do
        it("cannot explicitly cast from " .. t .. " to string", function()
            local prog_ast, errs = run_checker([[
                function fn(a: ]] .. t .. [[): string
                    return a as string
                end
            ]])
            assert.falsy(prog_ast)
            assert.match("cannot cast", errs)
        end)
    end

    it("catches assignment to function", function ()
        local prog_ast, errs = run_checker([[
            function f()
            end

            function g()
                f = g
            end
        ]])
        assert.falsy(prog_ast)
        assert.match(
            "attempting to assign to toplevel constant function f",
            errs, nil, true)
    end)

    it("typechecks io.write", function()
        local prog_ast, errs = run_checker([[
            function f()
                io_write("Hello World\n")
            end
        ]])
        assert.truthy(prog_ast, errs)
    end)

    it("typechecks io.write (error)", function()
        local prog_ast, errs = run_checker([[
            function f()
                io_write(17)
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("expected string but found integer", errs, nil, true)
    end)

    it("typechecks table.insert", function()
        local prog_ast, errs = run_checker([[
            function f(xs: {integer})
                table_insert(xs, 10)
            end

            function g(xs: {float})
                table_insert(xs, 3.14)
            end
        ]])
        assert.truthy(prog_ast, errs)
    end)

    it("typechecks table.insert (error)", function()
        local prog_ast, errs = run_checker([[
            function f(xs: {integer})
                table_insert(xs, "asd")
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("expected integer but found string", errs, nil, true)
    end)

    it("typechecks tofloat", function()
        local prog_ast, errs = run_checker([[
            function fn(): integer
                local i: integer = 12
                local f: float = tofloat(i)
                return 1
            end
        ]])
        assert.truthy(prog_ast, errs)
    end)
end)

describe("Pallene typecheck of records", function()
    it("typechecks record declarations", function()
        assert_type_check([[
            record Point
                x: float
                y: float
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

    local function wrap_record(code)
        return [[
            record Point x: float; y:float end

            function f(p: Point): float
                ]].. code ..[[
            end
        ]]
    end

    it("typechecks record read/write", function()
        assert_type_check(wrap_record[[
            local x: float = 10.0
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
        assert_type_error("Point is not assignable to float",
                          wrap_record[[ p.x = p ]])
        assert_type_error("float is not assignable to Point",
                          wrap_record[[ local p: Point = p.x ]])
    end)
end)

