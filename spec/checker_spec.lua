local driver = require 'pallene.driver'
local util = require 'pallene.util'

local function run_checker(code)
    assert(util.set_file_contents("test.pln", code))
    local prog_ast, errs = driver.test_ast("checker", "test.pln")
    return prog_ast, table.concat(errs, "\n")
end

local function assert_type_error(code, expected_err)
    local prog_ast, errs = run_checker(code)
    assert.falsy(prog_ast)
    assert.match(expected_err, errs, 1, true)
end

describe("Pallene type checker", function()

    teardown(function()
        os.remove("test.pln")
    end)

    it("detects when a non-type is used in a type variable", function()
        assert_type_error([[
            local foo: integer = 10
            local bar: foo = 11
        ]],
            "'foo' isn't a type")
    end)

    it("detects when a non-value is used in a value variable", function()
        assert_type_error([[
            record Point
                x: integer
                y: integer
            end
            local bar: integer = Point
        ]],
            "'Point' isn't a value")
    end)

    it("catches array expression in indexing is not an array", function()
        assert_type_error([[
            function fn(x: integer)
                x[1] = 2
            end
        ]],
            "expected array but found integer in array indexing")
    end)

    it("catches wrong use of length operator", function()
        assert_type_error([[
            function fn(x: integer): integer
                return #x
            end
        ]],
            "trying to take the length")
    end)

    it("catches wrong use of unary minus", function()
        assert_type_error([[
            function fn(x: boolean): boolean
                return -x
            end
        ]],
            "trying to negate a")
    end)

    it("catches wrong use of bitwise not", function()
        assert_type_error([[
            function fn(x: boolean): boolean
                return ~x
            end
        ]],
            "trying to bitwise negate a")
    end)

    it("catches wrong use of boolean not", function()
        assert_type_error([[
            function fn(): boolean
                return not nil
            end
        ]],
            "trying to boolean negate a nil")
    end)

    it("catches mismatching types in locals", function()
        assert_type_error([[
            function fn()
                local i: integer = 1
                local s: string = "foo"
                s = i
            end
        ]],
            "expected string but found integer in assignment")
    end)

    it("catches mismatching types in arguments", function()
        assert_type_error([[
            function fn(i: integer, s: string): integer
                s = i
            end
        ]],
            "expected string but found integer in assignment")
    end)

    it("forbids empty array (without type annotation)", function()
        assert_type_error([[
            local xs = {}
        ]],
            "missing type hint for array or record initializer")
    end)

    it("forbids non-empty array (without type annotation)", function()
        assert_type_error([[
            local xs = {10, 20, 30}
        ]],
            "missing type hint for array or record initializer")
    end)

    it("forbids array initializers with a table part", function()
        assert_type_error([[
            local xs: {integer} = {10, 20, 30, x=17}
        ]],
            "named field x in array initializer")
    end)

    it("forbids wrong type in array initializer", function()
        assert_type_error([[
            local xs: {integer} = {10, "hello"}
        ]],
            "expected integer but found string in array initializer")
    end)

    it("forbids record creation (without type annotation)", function()
        assert_type_error([[
            record Point
                x: float
                y: float
            end
            local p = { x = 10.0, y = 20.0 }
        ]],
            "missing type hint for array or record initializer")
    end)

    it("forbids wrong type in record initializer", function()
        assert_type_error([[
            record Point
                x: float
                y: float
            end
            local p: Point = { x = 10.0, y = "hello" }
        ]],
            "expected float but found string in record initializer")
    end)

    it("forbids wrong field name in record initializer", function()
        assert_type_error([[
            record Point
                x: float
                y: float
            end
            local p: Point = { x = 10.0, y = 20.0, z = 30.0 }
        ]],
            "invalid field z in record initializer for Point")
    end)

    it("forbids array part in record initializer", function()
        assert_type_error([[
            record Point
                x: float
                y: float
            end
            local p: Point = { x = 10.0, y = 20.0, 30.0 }
        ]],
            "record initializer has array part")
    end)

    it("forbids initializing a record field twice", function()
        assert_type_error([[
            record Point
                x: float
                y: float
            end
            local p: Point = { x = 10.0, x = 11.0, y = 20.0 }
        ]],
            "duplicate field x in record initializer")
    end)

    it("forbids missing fields in record initializer", function()
        assert_type_error([[
            record Point
                x: float
            end
            local p: Point = { }
        ]],
            "required field x is missing")
    end)

    it("forbids type hints that are not array or records", function()
        assert_type_error([[
            local p: string = { 10, 20, 30 }
        ]],
            "type hint for array or record initializer is not an array or record type")
    end)

    it("forbids array of nil", function()
        assert_type_error([[
            local xs: {nil} = {}
        ]],
            "array of nil is not allowed")
    end)

    it("requires while statement conditions to be boolean", function()
        assert_type_error([[
            function fn(x:integer): integer
                while x do
                    return 10
                end
                return 20
            end
        ]],
            "expected boolean but found integer in while loop condition")
    end)

    it("requires repeat statement conditions to be boolean", function()
        assert_type_error([[
            function fn(x:integer): integer
                repeat
                    return 10
                until x
                return 20
            end
        ]],
            "expected boolean but found integer in repeat-until loop condition")
    end)

    it("requires if statement conditions to be boolean", function()
        assert_type_error([[
            function fn(x:integer): integer
                if x then
                    return 10
                else
                    return 20
                end
            end
        ]],
            "expected boolean but found integer in if statement condition")
    end)

    it("ensures numeric 'for' variable has number type", function()
        assert_type_error([[
            function fn(x: integer, s: string): integer
                for i: string = 1, 10, 2 do
                    x = x + i
                end
                return x
            end
        ]],
            "expected integer or float but found string in for-loop control variable 'i'")
    end)

    it("catches 'for' errors in the start expression", function()
        assert_type_error([[
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
        assert_type_error([[
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
        assert_type_error([[
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
        assert_type_error([[
            function f(): ()
                return 1
            end
        ]],
            "returning 1 value(s) but function expects 0")
    end)

    it("detects too few return values", function()
        assert_type_error([[
            function f(): integer
                return
            end
        ]],
            "returning 0 value(s) but function expects 1")
    end)

    it("detects when a function returns the wrong type", function()
        assert_type_error([[
            function fn(): integer
                return "hello"
            end
        ]],
            "expected integer but found string in return statement")
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
            assert_type_error(c,"control reaches end of function with non-empty return type")
        end
    end)

    it("rejects void functions in expression contexts", function()
        assert_type_error([[
            local function f(): ()
            end

            local function g(): integer
                return 1 + f()
            end
        ]],
            "void instead of a number")
    end)

    it("detects attempts to call non-functions", function()
        assert_type_error([[
            function fn(): integer
                local i: integer = 0
                i()
            end
        ]],
            "attempting to call a integer value")
    end)

    it("detects wrong number of arguments to functions", function()
        assert_type_error([[
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
        assert_type_error([[
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
                assert_type_error(test_program, err_msg)
            end)
        end
    end)


    local function optest(err_template, program_template, opts)
        local err_msg = util.render(err_template, opts)
        local test_program = util.render(program_template, opts)
        it(err_msg, function()
            assert_type_error(test_program, err_msg)
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
       "$dir hand side of logical expression is a $t instead of a boolean", [[
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

    describe("casting:", function()
        local typs = {
            "boolean", "float", "integer", "nil", "string",
            "{ integer }", "{ float }",
        }
        for _, t1 in ipairs(typs) do
            for _, t2 in ipairs(typs) do
                if t1 ~= t2 then
                    optest("cannot cast $t1 to $t2", [[
                        function fn(a: $t1) : $t2
                            return a as $t2
                        end
                    ]], { t1 = t1, t2 = t2 })
                end
            end
        end
    end)

    it("catches assignment to function", function ()
        assert_type_error([[
            function f()
            end

            function g()
                f = g
            end
        ]],
            "attempting to assign to toplevel constant function f")
    end)

    it("typechecks io.write (error)", function()
        assert_type_error([[
            function f()
                io_write(17)
            end
        ]],
            "expected string but found integer in argument 1")
    end)

    it("typechecks table.insert (error)", function()
        assert_type_error([[
            function f(xs: {integer})
                table_insert("asd", xs)
            end
        ]],
            "expected { value } but found string in argument 1")
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
            assert_type_error(wrap_record(code),
                "field 'nope' not found in record 'Point'")
        end
        assert_non_existent([[ p.nope = 10 ]])
        assert_non_existent([[ return p.nope ]])
    end)

    it("doesn't typecheck read/write with invalid types", function()
        assert_type_error(wrap_record[[ p.x = p ]],
            "expected float but found Point in assignment")
        assert_type_error(wrap_record[[ local p: Point = p.x ]],
            "expected Point but found float in declaration")
    end)
end)
