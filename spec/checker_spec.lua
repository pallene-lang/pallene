local driver = require 'pallene.driver'
local util = require 'pallene.util'

local function run_checker(code)
    assert(util.set_file_contents("test.pln", code))
    local prog_ast, errs = driver.test_ast("checker", "test.pln")
    return prog_ast, table.concat(errs, "\n")
end

local function assert_type_error(expected, code)
    local prog_ast, errs = run_checker(code)
    assert.falsy(prog_ast)
    assert.match(expected, errs)
end

describe("Pallene type checker", function()

    teardown(function()
        os.remove("test.pln")
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

    it("catches array expression in indexing is not an array", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer)
                x[1] = 2
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("expected array but found integer in array indexing", errs)
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
        assert.match("expected string but found integer in assignment", errs)
    end)

    it("catches mismatching types in arguments", function()
        local prog_ast, errs = run_checker([[
            function fn(i: integer, s: string): integer
                s = i
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("expected string but found integer in assignment", errs)
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
        assert.matches("expected integer but found string in array initializer", errs)
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
        assert.matches("expected float but found string in record initializer", errs)
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
        assert.matches("expected boolean but found integer in while loop condition", errs)
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
        assert.matches("expected boolean but found integer in repeat%-until loop condition", errs)
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
        assert.matches("expected boolean but found integer in if statement condition", errs)
    end)

    it("ensures numeric 'for' variable has number type", function()
        local prog_ast, errs = run_checker([[
            function fn(x: integer, s: string): integer
                for i: string = 1, 10, 2 do
                    x = x + i
                end
                return x
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("expected integer or float but found string in for%-loop control variable 'i'", errs)
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
        assert.match("expected integer but found string in numeric for%-loop initializer", errs)
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
        assert.match("expected integer but found string in numeric for%-loop limit", errs)
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
        assert.match("expected integer but found string in numeric for%-loop step", errs)
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

    it("detects when a function returns the wrong type", function()
        local prog_ast, errs = run_checker([[
            function fn(): integer
                return "hello"
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("expected integer but found string in return statement", errs)
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
        assert.match("expected integer but found float in argument 1 of call to function", errs)
    end)

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

    for _, op in ipairs({"==", "~="}) do
        it("cannot compare arrays of different types using " .. op, function()
            local prog_ast, errs = run_checker([[
                function fn(a1: {integer}, a2: {float}): boolean
                    return a1 ]] .. op .. [[ a2
                end
            ]])
            assert.falsy(prog_ast)
            assert.match("cannot compare .* and .* using .*", errs)
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
                        assert.match("cannot compare .* and .* using .*", errs)
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
                assert.match("cannot compare .* and .* using .*", errs)
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
                assert.match("cannot compare .* and .* using .*", errs)
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
                assert.match("cannot compare .* and .* using .*", errs)
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
                assert.match("cannot compare .* and .* using .*", errs)
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
                assert.match("cannot compare .* and .* using .*", errs)
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
                assert.match("cannot compare .* and .* using .*", errs)
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
                    assert.match("cannot compare .* and .* using .*", errs)
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

    it("typechecks io.write (error)", function()
        local prog_ast, errs = run_checker([[
            function f()
                io_write(17)
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("expected string but found integer in argument 1", errs, nil, true)
    end)

    it("typechecks table.insert (error)", function()
        local prog_ast, errs = run_checker([[
            function f(xs: {integer})
                table_insert("asd", xs)
            end
        ]])
        assert.falsy(prog_ast)
        assert.match("expected { value } but found string in argument 1", errs, nil, true)
    end)
end)

describe("Pallene typecheck of records", function()
    local function wrap_record(code)
        return [[
            record Point x: float; y:float end

            function f(p: Point): float
                ]].. code ..[[
            end
        ]]
    end

    it("doesn't typecheck read/write to non existent fields", function()
        local function assert_non_existent(code)
            assert_type_error("field 'nope' not found in record 'Point'",
                              wrap_record(code))
        end
        assert_non_existent([[ p.nope = 10 ]])
        assert_non_existent([[ return p.nope ]])
    end)

    it("doesn't typecheck read/write with invalid types", function()
        assert_type_error("expected float but found Point in assignment",
                          wrap_record[[ p.x = p ]])
        assert_type_error("expected Point but found float in declaration",
                          wrap_record[[ local p: Point = p.x ]])
    end)
end)
