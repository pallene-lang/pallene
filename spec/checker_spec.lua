local driver = require 'pallene.driver'
local util = require 'pallene.util'

local function run_checker(code)
    assert(util.set_file_contents("test.pln", code))
    local module, errs = driver.compile_internal("test.pln", "checker")
    return module, table.concat(errs, "\n")
end

local function assert_error(code, expected_err)
    local module, errs = run_checker(code)
    assert.falsy(module)
    assert.match(expected_err, errs, 1, true)
end

describe("Scope analysis: ", function()

    teardown(function()
        os.remove("test.pln")
    end)

    it("forbids variables from being used before they are defined", function()
        assert_error([[
            function fn(): nil
                x = 17
                local x = 18
            end
        ]],
            "variable 'x' is not declared")
    end)

    it("forbids type variables from being used before they are defined", function()
        assert_error([[
            function fn(p: Point): integer
                return p.x
            end

            record Point
                x: integer
                y: integer
            end
        ]],
            "type 'Point' is not declared")
    end)

    it("do-end limits variable scope", function()
        assert_error([[
            function fn(): nil
                do
                    local x = 17
                end
                x = 18
            end
        ]],
            "variable 'x' is not declared")
    end)

    it("forbids mutually recursive definitions", function()
        assert_error([[
            local function foo(): integer
                return bar()
            end

            local function bar(): integer
                return foo()
            end
        ]],
            "variable 'bar' is not declared")
    end)

    it("forbids multiple toplevel declarations with the same name", function()
        assert_error([[
            local function f() end
            local function f() end
        ]],
            "duplicate toplevel declaration for 'f'")
    end)

    it("forbids multiple function arguments with the same name", function()
        assert_error([[
            function fn(x: integer, x:string)
            end
        ]],
            "function has multiple parameters named 'x'")
    end)

    it("forbids typealias to non-existent type", function()
        assert_error([[
            type point = foo
        ]],
            "type 'foo' is not declared")
    end)

    it("forbids recursive typealias", function()
        assert_error([[
            type point = {point}
        ]],
            "type 'point' is not declared")
    end)

    it("forbids typealias to non-type name", function()
        assert_error([[
            local x: integer = 0
            type point = x
        ]],
            "type error: 'x' isn't a type")
    end)
end)

describe("Pallene type checker", function()

    teardown(function()
        os.remove("test.pln")
    end)

    it("detects when a non-type is used in a type variable", function()
        assert_error([[
            function fn()
                local foo: integer = 10
                local bar: foo = 11
            end
        ]],
            "'foo' isn't a type")
    end)

    it("detects when a non-value is used in a value variable", function()
        assert_error([[
            record Point
                x: integer
                y: integer
            end
            function fn()
                local bar: integer = Point
            end
        ]],
            "'Point' isn't a value")
    end)

    it("catches table type with repeated fields", function()
        assert_error([[
            function fn(t: {x: float, x: integer}) end
        ]],
            "duplicate field 'x' in table")
    end)

    it("catches array expression in indexing is not an array", function()
        assert_error([[
            function fn(x: integer)
                x[1] = 2
            end
        ]],
            "expected array but found integer in array indexing")
    end)

    it("catches wrong use of length operator", function()
        assert_error([[
            function fn(x: integer): integer
                return #x
            end
        ]],
            "trying to take the length")
    end)

    it("catches wrong use of unary minus", function()
        assert_error([[
            function fn(x: boolean): boolean
                return -x
            end
        ]],
            "trying to negate a")
    end)

    it("catches wrong use of bitwise not", function()
        assert_error([[
            function fn(x: boolean): boolean
                return ~x
            end
        ]],
            "trying to bitwise negate a")
    end)

    it("catches wrong use of boolean not", function()
        assert_error([[
            function fn(): boolean
                return not nil
            end
        ]],
            "expression passed to 'not' operator has type nil")
    end)

    it("catches mismatching types in locals", function()
        assert_error([[
            function fn()
                local i: integer = 1
                local s: string = "foo"
                s = i
            end
        ]],
            "expected string but found integer in assignment")
    end)

    it("requires a type annotation for an uninitialized variable", function()
        assert_error([[
            function fn(): integer
                local x
                x = 10
                return x
            end
        ]], "uninitialized variable 'x' needs a type annotation")
    end)

    it("catches mismatching types in arguments", function()
        assert_error([[
            function fn(i: integer, s: string): integer
                s = i
            end
        ]],
            "expected string but found integer in assignment")
    end)

    it("forbids empty array (without type annotation)", function()
        assert_error([[
            function fn()
                local xs = {}
            end
        ]],
            "missing type hint for initializer")
    end)

    it("forbids non-empty array (without type annotation)", function()
        assert_error([[
            function fn()
                local xs = {10, 20, 30}
            end
        ]],
            "missing type hint for initializer")
    end)

    it("forbids array initializers with a table part", function()
        assert_error([[
            function fn()
                local xs: {integer} = {10, 20, 30, x=17}
            end
        ]],
            "named field 'x' in array initializer")
    end)

    it("forbids wrong type in array initializer", function()
        assert_error([[
            function fn()
                local xs: {integer} = {10, "hello"}
            end
        ]],
            "expected integer but found string in array initializer")
    end)

    describe("table/record initalizer", function()
        local function assert_init_error(code, err)
            assert_error([[
                record Point x: float; y:float end

                function f(): float
                    ]].. code ..[[
                end
            ]], err)
        end

        for _, typ in ipairs({"{ x: float, y: float }", "Point"}) do

            it("forbids creation without type annotation", function()
                assert_init_error([[
                    local p = { x = 10.0, y = 20.0 }
                ]],
                    "missing type hint for initializer")
            end)

            it("forbids wrong type in initializer", function()
                assert_init_error([[
                    local p: Point = { x = 10.0, y = "hello" }
                ]],
                    "expected float but found string in table initializer")
            end)

            it("forbids wrong field name in initializer", function()
                assert_init_error([[
                    local p: Point = { x = 10.0, y = 20.0, z = 30.0 }
                ]],
                    "invalid field 'z' in table initializer for Point")
            end)

            it("forbids array part in initializer", function()
                assert_init_error([[
                    local p: Point = { x = 10.0, y = 20.0, 30.0 }
                ]],
                    "table initializer has array part")
            end)

            it("forbids initializing a field twice", function()
                assert_init_error([[
                    local p: Point = { x = 10.0, x = 11.0, y = 20.0 }
                ]],
                    "duplicate field 'x' in table initializer")
            end)

            it("forbids missing fields in initializer", function()
                assert_init_error([[
                    local p: Point = { y = 1.0 }
                ]],
                    "required field 'x' is missing")
            end)
        end
    end)

    it("forbids type hints that are not array, tables, or records", function()
        assert_error([[
            function fn()
                local p: string = { 10, 20, 30 }
            end
        ]],
            "type hint for initializer is not an array, table, or record type")
    end)

    it("requires while statement conditions to be boolean", function()
        assert_error([[
            function fn(x:integer): integer
                while x do
                    return 10
                end
                return 20
            end
        ]],
            "expression passed to while loop condition has type integer")
    end)

    it("requires repeat statement conditions to be boolean", function()
        assert_error([[
            function fn(x:integer): integer
                repeat
                    return 10
                until x
                return 20
            end
        ]],
            "expression passed to repeat-until loop condition has type integer")
    end)

    it("requires if statement conditions to be boolean", function()
        assert_error([[
            function fn(x:integer): integer
                if x then
                    return 10
                else
                    return 20
                end
            end
        ]],
            "expression passed to if statement condition has type integer")
    end)

    it("ensures numeric 'for' variable has number type", function()
        assert_error([[
            function fn(x: integer, s: string): integer
                for i: string = "hello", 10, 2 do
                    x = x + i
                end
                return x
            end
        ]],
            "expected integer or float but found string in for-loop control variable 'i'")
    end)

    it("catches 'for' errors in the start expression", function()
        assert_error([[
            function fn(x: integer, s: string): integer
                for i:integer = s, 10, 2 do
                    x = x + i
                end
                return x
            end
        ]],
            "expected integer but found string in numeric for-loop initializer")
    end)

    it("catches 'for' errors in the limit expression", function()
        assert_error([[
            function fn(x: integer, s: string): integer
                for i = 1, s, 2 do
                    x = x + i
                end
                return x
            end
        ]],
            "expected integer but found string in numeric for-loop limit")
    end)

    it("catches 'for' errors in the step expression", function()
        assert_error([[
            function fn(x: integer, s: string): integer
                for i = 1, 10, s do
                    x = x + i
                end
                return x
            end
        ]],
            "expected integer but found string in numeric for-loop step")
    end)

    it("detects too many return values", function()
        assert_error([[
            function f(): ()
                return 1
            end
        ]],
            "returning 1 value(s) but function expects 0")
    end)

    it("detects too few return values", function()
        assert_error([[
            function f(): integer
                return
            end
        ]],
            "returning 0 value(s) but function expects 1")
    end)

    it("detects when a function returns the wrong type", function()
        assert_error([[
            function fn(): integer
                return "hello"
            end
        ]],
            "expected integer but found string in return statement")
    end)

    it("rejects void functions in expression contexts", function()
        assert_error([[
            local function f(): ()
            end

            local function g(): integer
                return 1 + f()
            end
        ]],
            "void instead of a number")
    end)

    it("detects attempts to call non-functions", function()
        assert_error([[
            function fn(): integer
                local i: integer = 0
                i()
            end
        ]],
            "attempting to call a integer value")
    end)

    it("detects wrong number of arguments to functions", function()
        assert_error([[
            function f(x: integer, y: integer): integer
                return x + y
            end

            function g(): integer
                return f(1)
            end
        ]],
            "function expects 2 argument(s) but received 1")
    end)

    it("detects wrong types of arguments to functions", function()
        assert_error([[
            function f(x: integer, y: integer): integer
                return x + y
            end

            function g(): integer
                return f(1.0, 2.0)
            end
        ]],
            "expected integer but found float in argument 1 of call to function")
    end)

    describe("concatenation", function()
        for _, typ in ipairs({"boolean", "nil", "{ integer }"}) do
            local err_msg = string.format(
                "cannot concatenate with %s value", typ)
            local test_program = util.render([[
                function fn(x : $typ) : string
                    return "hello " .. x
                end
            ]], { typ = typ })

            it(err_msg, function()
                assert_error(test_program, err_msg)
            end)
        end
    end)


    local function optest(err_template, program_template, opts)
        local err_msg = util.render(err_template, opts)
        local test_program = util.render(program_template, opts)
        it(err_msg, function()
            assert_error(test_program, err_msg)
        end)
    end

    describe("equality:", function()
        local ops = { "==", "~=" }
        local typs = {
            "integer", "boolean", "float", "string", "{ integer }", "{ float }"
        }
        for _, op in ipairs(ops) do
            for _, t1 in ipairs(typs) do
                for _, t2 in ipairs(typs) do
                    if not (t1 == t2) and
                        not (t1 == "integer" and t2 == "float") and
                        not (t1 == "float" and t2 == "integer")
                    then
                        optest("cannot compare $t1 and $t2 using $op", [[
                            function fn(a: $t1, b: $t2): boolean
                                return a $op b
                             end
                        ]], {
                            op = op, t1 = t1, t2 = t2
                        })
                    end
                end
            end
        end
    end)

    describe("and/or:", function()
        for _, op in ipairs({"and", "or"}) do
            for _, t in ipairs({"{ integer }", "integer", "string"}) do
                for _, test in ipairs({
                    { "left", t, "boolean" },
                    { "right", "boolean", t },
                }) do
                    local dir, t1, t2 = test[1], test[2], test[3]
                    optest(
       "$dir hand side of '$op' has type $t", [[
                        function fn(x: $t1, y: $t2) : boolean
                            return x $op y
                        end
                    ]], { op = op, t = t, dir = dir, t1 = t1, t2=t2 })
                end
            end
        end
    end)

    describe("bitwise:", function()
        for _, op in ipairs({"|", "&", "<<", ">>"}) do
            for _, t in ipairs({"{ integer }", "boolean", "string"}) do
                for _, test in ipairs({
                    { "left", t, "integer" },
                    { "right", "integer", t },
                }) do
                    local dir, t1, t2 = test[1], test[2], test[3]
                    optest(
        "$dir hand side of bitwise expression is a $t instead of an integer", [[
                        function fn(a: $t1, b: $t2): integer
                            return a $op b
                        end
                    ]], { op = op, t = t, dir = dir, t1 = t1, t2 = t2 })
                end
            end
        end
    end)

    describe("arithmetic:", function()
        for _, op in ipairs({"+", "-", "*", "//", "/", "^"}) do
            for _, t in ipairs({"{ integer }", "boolean", "string"}) do
                for _, test in ipairs({
                    { "left", t, "float" },
                    { "right", "float", t },
                }) do
                    local dir, t1, t2 = test[1], test[2], test[3]
                    optest(
        "$dir hand side of arithmetic expression is a $t instead of a number", [[
                        function fn(a: $t1, b: $t2) : float
                            return a $op b
                        end
                    ]], { op = op, t = t, dir = dir, t1 = t1, t2 = t2} )
                end
            end
        end
    end)

    describe("dot", function()
        for _, typ in ipairs({"{ x: float, y: float }", "Point"}) do
            local function assert_dot_error(code, err)
                assert_error([[
                    record Point x: float; y:float end

                    function f(p: ]].. typ ..[[): float
                        ]].. code ..[[
                    end
                ]], err)
            end

            it("doesn't typecheck read/write to non existent fields", function()
                local err = "field 'nope' not found in type '".. typ .."'"
                assert_dot_error([[ p.nope = 10 ]], err)
                assert_dot_error([[ return p.nope ]], err)
            end)

            it("doesn't typecheck read/write with invalid types", function()
                assert_dot_error([[ p.x = p ]],
                    "expected float but found ".. typ .." in assignment")
                assert_dot_error([[ local p: ]].. typ ..[[ = p.x ]],
                    "expected ".. typ .." but found float in declaration")
            end)
        end
    end)

    describe("casting:", function()
        local typs = {
            "boolean", "float", "integer", "nil", "string",
            "{ integer }", "{ float }",
        }
        for _, t1 in ipairs(typs) do
            for _, t2 in ipairs(typs) do
                if t1 ~= t2 then
                    optest("expected $t2 but found $t1 in cast expression", [[
                        function fn(a: $t1) : $t2
                            return a as $t2
                        end
                    ]], { t1 = t1, t2 = t2 })
                end
            end
        end
    end)

    it("catches assignment to function", function ()
        assert_error([[
            function f()
            end

            function g()
                f = g
            end
        ]],
            "attempting to assign to toplevel constant function 'f'")
    end)

    it("typechecks io.write (error)", function()
        assert_error([[
            function f()
                io_write(17)
            end
        ]],
            "expected string but found integer in argument 1")
    end)
end)
