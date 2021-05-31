local driver = require 'pallene.driver'
local util = require 'pallene.util'

-- Organization of the Checker Test Suite
-- --------------------------------------
--
-- Try to order the tests by the order that things appear in parser.lua.
-- This way, it's easier to know if a test case is missing.
--
-- Try to have a test case for every named error. Look for functions in the checker.lua that take
-- an error string as a paremeter. For example, type_error and check_exp_verify.

local function run_checker(code)
    -- "__test__.pln" does not exist on disk. The name is only used for error messages.
    local module, errs = driver.compile_internal("__test__.pln", code, "checker")
    return module, table.concat(errs, "\n")
end

local function assert_error(body, expected_err)
    local module, errs = run_checker(util.render([[
        local m: module = {}
        $body
        return m
    ]], {
        body = body
    }))
    assert.falsy(module)
    assert.match(expected_err, errs, 1, true)
end

--
-- Type
--

describe("Type variable", function()

    it("must be a name in scope", function()
        assert_error([[
            function m.fn(p: Point): integer
                return p.x
            end
            record Point
                x: integer
                y: integer
            end
        ]], "type 'Point' is not declared")
    end)

    it("must be a type name (not a module)", function()
        assert_error([[
            local x : m = 1
        ]], "module 'm' is not a type")
    end)

    it("must be a type name (not a value)", function()
        assert_error([[
            local x = 1
            local y: x = 2
        ]], "'x' is not a type")
    end)
end)

describe("Table type", function()

    it("must not have duplicate field names", function()
        assert_error([[
            function m.fn(t: {x: float, x: integer}) end
        ]], "duplicate field 'x' in table")
    end)

end)

--
-- Program
--

describe("Module", function()

    it("must not shadow the module variable", function()
        assert_error([[
            local m = 10
        ]], "the module variable 'm' is being shadowed")
    end)

    it("forbids repeated exported names (function / function)", function()
        assert_error([[
            function m.f() end
            function m.f() end
        ]], "multiple definitions for module field 'f'")
    end)

    it("forbids repeated exported names (function / variable)", function()
        assert_error([[
            function m.f() end
            m.f = 1
        ]], "multiple definitions for module field 'f'")
    end)

    it("forbids repeated exported names (variable / variable)", function()
        assert_error([[
            m.x = 10
            m.x = 20
        ]], "multiple definitions for module field 'x'")
    end)

    it("forbids repeated exported names (in multiple assignment)", function()
        assert_error([[
            m.x, m.x = 10, 20
        ]], "multiple definitions for module field 'x'")
    end)

    it("ensures that exported variables are not in scope in their initializers", function()
        assert_error([[
            m.x = m.x
        ]], "module field 'x' does not exist")
    end)

end)

--
-- Toplevel
--

describe("Typealias", function()

    it("is not recursive", function()
        assert_error([[
            typealias point = {point}
        ]], "type 'point' is not declared")
    end)

    it("must be a type", function()
        assert_error([[
            local t: integer = 0
            typealias point = t
        ]], "'t' is not a type")
    end)

end)

describe("Function declaration", function()

    it("must set a field in a module (1/2)", function()
        assert_error([[
            function c.f() end
        ]], "module 'c' is not declared")
    end)

    it("must set a field in a module (2/2)", function()
        assert_error([[
            local c = 10
            function c.f() end
        ]], "'c' is not a module")
    end)

    it("must only appear at the toplevel", function()
        assert_error([[
            function m.f()
                function m.g() end
            end
        ]], "module functions can only be set at the toplevel")
    end)

    it("must not assign to other modules", function()
        assert_error([[
            function io.f()
            end
        ]], "attempting to assign a function to an external module")
    end)

    it("must have a namespace that is a single level deep", function()
        assert_error([[
            function m.f.g() end
        ]], "more than one dot in the function name is not allowed")
    end)

    it("does not allow global functions", function()
        assert_error([[
            function f(): integer
                return 5319
            end
        ]], "function 'f' was not forward declared")
    end)

end)

--
-- Stat
--

describe("Local variable declaration", function()

    it("requires a type annotation for an uninitialized variable", function()
        assert_error([[
            function m.fn(): integer
                local x
                x = 10
                return x
            end
        ]], "uninitialized variable 'x' needs a type annotation")
    end)

    it("checks that initializers match the type annotation", function()
        assert_error([[
            local x: string = false
        ]], "expected string but found boolean in declaration of local variable 'x'")
    end)

    it("checks extra expressions in right-hand side", function()
        assert_error([[
            function m.f()
                local x = 10, 20+"Boom"
            end
        ]], "right-hand side of arithmetic expression is a string instead of a number")
    end)

    it("does not include the variable in the scope of its initializer", function()
        assert_error([[
            local a = a
        ]], "variable 'a' is not declared")
    end)

end)

describe("Repeat-until loop", function()

    it("include the inner variables in the scope of the condition", function()
        assert_error([[
            function m.f()
                local x = false
                repeat
                    local x = "hello"
                until x
            end
        ]], "expression passed to repeat-until loop condition has type string")
    end)

end)

describe("Numeric for-loop", function()

    it("must have a numeric loop variable", function()
        assert_error([[
            function m.fn(x: integer, s: string)
                for i = s, 20, 2 do
                end
            end
        ]], "expected integer or float but found string in for-loop control variable 'i'")
    end)

    it("checks the type of the start expression", function()
        assert_error([[
            function m.fn(x: integer, s: string)
                for i:integer = s, 10, 2 do
                end
            end
        ]], "expected integer but found string in numeric for-loop initializer")
    end)

    it("checks the type of the limit expression", function()
        assert_error([[
            function m.fn(x: integer, s: string)
                for i = 1, s, 2 do
                end
            end
        ]], "expected integer but found string in numeric for-loop limit")
    end)

    it("checks the type of the step expression", function()
        assert_error([[
            function m.fn(x: integer, s: string)
                for i = 1, 10, s do
                end
            end
        ]], "expected integer but found string in numeric for-loop step")
    end)

end)

describe("For-in loop", function()

    -- TODO https://github.com/pallene-lang/pallene/issues/378
    pending("must have a right-hand side", function()
        assert_error([[
            local function voidfn()
            end
            function m.fn()
                for k, v in voidfn() do
                end
            end
        ]], "missing right-hand side in for-in loop")
    end)

    it("must have a RHS with 3 values (missing state variable)", function()
        assert_error([[
            function m.iter(a: any, b: any): (any, any)
                return 1, 2
            end

            function m.fn()
                for k, v in m.iter do
                    k = v
                end
            end
        ]], "missing state variable in for-in loop")
    end)

    it("must have a RHS with 3 values (missing control variable)", function()
        assert_error([[
            function m.iter(a: any, b: any): (any, any)
                return 1, 2
            end

            function m.ipairs(): ((any, any) -> (any, any), integer)
                return m.iter, 4
            end

            function m.fn()
                for k, v in m.ipairs() do
                end
            end
        ]], "missing control variable in for-in loop")
    end)

    it("checks the type of the iterator (1/2)", function()
        assert_error([[
            function m.foo(a: integer, b: integer): integer
                return a * b
            end

            function m.fn()
                for k, v in m.foo, 1, 2 do
                    local a = k + v
                end
            end
        ]], "expected 1 variable(s) in for loop but found 2")
    end)

    it("checks the type of the iterator (2/2)", function()
        assert_error([[
            function m.fn()
                for k, v in 5, 1, 2 do
                    local a = k + v
                end
            end
        ]], "expected function type (any, any) -> (any, any) but found integer in loop iterator")
    end)

    it("checks the type of the state and control values", function()
        assert_error([[
            function m.foo(): (integer, integer)
                return 1, 2
            end

            function m.iter(a: any, b: any): (any, any)
                return 1, 2
            end

            function m.fn()
                for k, v in m.iter, m.foo() do
                    local a = k + v
                end
            end
        ]], "expected any but found integer in loop state value")
    end)

end)

describe("Assignment statement", function()

    it("can only export a variable in the toplevel", function()
        assert_error([[
            function m.f()
                m.x = 10
            end
        ]], "module fields can only be set at the toplevel")
    end)

    it("cannot reassign a function", function ()
        assert_error([[
            local function f()
            end

            function m.g()
                f = f
            end
        ]], "LHS of assignment is not a mutable variable")
    end)

    it("catches assignment to builtin (with correct type)", function ()
        assert_error([[
            function m.f(x: string)
            end

            function m.g()
                io.write = m.f
            end
        ]], "LHS of assignment is not a mutable variable")
    end)

    it("catches assignment to builtin (with wrong type)", function ()
        assert_error([[
            function m.f(x: integer)
            end

            function m.g()
                io.write = m.f
            end
        ]], "LHS of assignment is not a mutable variable")
    end)

end)


describe("Return statement", function()

    it("detects too few return values", function()
        assert_error([[
            function m.f(): integer
                return
            end
        ]], "returning 0 value(s) but function expects 1")
    end)

    it("detects too many return values", function()
        assert_error([[
            function m.f(): ()
                return 1
            end
        ]], "returning 1 value(s) but function expects 0")
    end)

    it("detects too many return values when returning a function call", function()
        assert_error([[
            local function f(): (integer, integer)
                return 1, 2
            end

            function m.g(): integer
                return f()
            end
        ]], "returning 2 value(s) but function expects 1")
    end)

    it("checks the type of the returned value", function()
        assert_error([[
            function m.fn(): integer
                return "hello"
            end
        ]], "expected integer but found string in return statement")
    end)

end)

--
-- Var
--

describe("Qualified name", function()

    it("must refer to an existing module field", function()
        assert_error([[
            local x = io.xyz
        ]], "module field 'xyz' does not exist")
    end)

end)

describe("Simple name", function()

    it("must be in scope", function()
        assert_error([[
            function m.fn()
                x = 17
                local x = 18
            end
        ]], "variable 'x' is not declared")
    end)

    it("must be in scope (do-end)", function()
        assert_error([[
            function m.fn()
                do
                    local x = 17
                end
                x = 18
            end
        ]], "variable 'x' is not declared")
    end)

    it("must not refer to a type (in expression)", function()
        assert_error([[
            function m.f()
                local _ = integer
            end
        ]], "type 'integer' is not a value")
    end)

    it("must not refer to a type (in assignment)", function()
        assert_error([[
            function m.f()
                integer = 10
            end
        ]], "type 'integer' is not a value")
    end)

    it("must not refer to a module (in expression)", function()
        assert_error([[
            function m.f()
                local _ = io
            end
        ]], "module 'io' is not a value")
    end)

    it("must not refer to a module (in assignment)", function()
        assert_error([[
            function m.f()
                io = 10
            end
        ]], "module 'io' is not a value")
    end)

end)


describe("Field acess (dot)", function()

    it("must be on an indexable type", function()
        assert_error([[
            local _ = ("t").x
        ]], "trying to access a member of a value of type 'string'")
    end)

    it("must be an existing field name", function()
        assert_error([[
            record Point
                x: integer
                y: integer
            end
            function m.f(p: Point)
                local _ = p.z
            end
        ]], "field 'z' not found in type 'Point'")
    end)

    it("checks the field type", function()
        assert_error([[
            record Point
                x: integer
                y: integer
            end
            function m.f(p: Point)
                p.x = "hello"
            end
        ]], "expected integer but found string in assignment")
    end)

end)

describe("Bracket", function()

    it("must be on an array", function()
        assert_error([[
            function m.fn(x: string)
                x[1] = 2
            end
        ]], "expected array but found string in indexed expression")
    end)

    it("must be on an integer index", function()
        assert_error([[
            function m.fn(x: {string})
                x[1.0] = 2
            end
        ]], "expected integer but found float in array index")
    end)

end)

--
-- Exp Synthesize
--

describe("Table literal", function()

    it("requires a type annotation (empty array)", function()
        assert_error([[
            function m.fn()
                local xs = {}
            end
        ]], "missing type hint for initializer")
    end)

    it("requires a type annotation (non-empty array)", function()
        assert_error([[
            function m.fn()
                local xs = {10, 20, 30}
            end
        ]], "missing type hint for initializer")
    end)

end)

describe("Lambda", function()

    it("requires a type annotation", function()
        assert_error([[
            local _ = function(x) return x end
        ]], "missing type hint for lambda")
    end)

end)

describe("Unary operator", function()

    local function test(op, typ, expected_error)
        local description = string.format(
            "'%s' does not allow the wrong type (%s)", op, typ)

        local code = util.render([[
            function m.fn(x: $typ)
                local _ = $op x
            end
        ]], { op = op, typ = typ })

        it(description, function()
            assert_error(code, expected_error)
        end)
    end

    test("#", "integer", "trying to take the length of")
    test("#", "any",     "trying to take the length of")

    test("-", "boolean", "trying to negate a")
    test("-", "any",     "trying to negate a")

    test("not", "integer", "expression passed to 'not' operator has type")
end)

describe("Binary operator", function()

    local function test(op, typ1, typ2, expected_error)
        local description = string.format(
            "'%s' does not allow the wrong type (%s, %s)", op, typ1, typ2)

        local code = util.render([[
            function m.fn(x: $typ1, y: $typ2)
                local _ = x $op y
            end
        ]], { op = op, typ1 = typ1, typ2 = typ2 })

        it(description, function()
            assert_error(code, expected_error)
        end)
    end

    -- Equality
    for _, op in ipairs({"==", "~="}) do
        test(op, "integer",   "string",  "cannot compare")
        test(op, "{integer}", "{float}", "cannot compare")
        test(op, "{x:float}", "{float}", "cannot compare")
        test(op, "{any}",     "{float}", "cannot compare")
        test(op, "integer",   "any",     "cannot compare")

        test(op, "integer",   "float",   "not yet implemented")
    end

    -- Relational
    for _, op in ipairs({"<", ">", "<=", ">=" }) do
        test(op, "integer",   "string",  "cannot compare")
        test(op, "{integer}", "{float}", "cannot compare")
        test(op, "{x:float}", "{float}", "cannot compare")
        test(op, "{any}",     "{float}", "cannot compare")
        test(op, "integer",   "any",     "cannot compare")

        test(op, "integer",   "float",   "not yet implemented")
    end

    -- Arithmetic
    for _, op in ipairs({"+", "-", "*", "//", "/", "^"}) do
        test(op, "string", "integer", "left-hand side of arithmetic")
        test(op, "any",    "integer", "left-hand side of arithmetic")

        test(op, "float", "string", "right-hand side of arithmetic")
        test(op, "float", "any",    "right-hand side of arithmetic")
    end

    -- Concatenation
    for _, op in ipairs({".."}) do
        test(op, "integer", "string", "cannot concatenate")
        test(op, "string", "integer", "cannot concatenate")
    end

    -- Boolean
    for _, op in ipairs({"and", "or"}) do
        test(op, "integer", "boolean", "first operand of")

        test(op, "boolean", "integer", "second operand of")
    end

    -- Bitwise
    for _, op in ipairs({"|", "&", "<<", ">>"}) do
        test(op, "boolean", "integer", "left-hand side of bitwise")
        test(op, "any",     "integer", "left-hand side of bitwise")

        test(op, "integer", "boolean", "right-hand side of bitwise")
        test(op, "integer", "any",     "right-hand side of bitwise")
    end

end)

describe("Cast operator", function()

    local function test(typ1, typ2, expected_error)
        local description = string.format(
            "'as' cannot convert incompatible types (%s, %s)", typ1, typ2)

        local code = util.render([[
            function m.fn(x: $typ1)
                local _ = x as $typ2
            end
        ]], { typ1 = typ1, typ2 = typ2 })

        it(description, function()
            assert_error(code, expected_error)
        end)
    end

    test("boolean", "float",     "in cast expression")
    test("nil",     "string",    "in cast expression")
    test("{float}", "{integer}", "in cast expression")
end)

describe("Function call", function()

    it("must be a function (non-any)", function()
        assert_error([[
            function m.fn(f: integer)
                f()
            end
        ]], "attempting to call a integer value")
    end)

    it("must be a function (any)", function()
        assert_error([[
            function m.fn(f: any)
                f()
            end
        ]], "attempting to call a any value")
    end)

    it("must have the correct number of arguments", function()
        assert_error([[
            function m.f(x: integer, y: integer): integer
                return x + y
            end

            function m.g(): integer
                return m.f(1)
            end
        ]], "function expects 2 argument(s) but received 1")
    end)

    it("detects too few arguments, when last argument is a function call", function()
        assert_error([[
            function m.f(): (integer, integer)
                return 1, 2
            end

            function m.g(x:integer, y:integer, z:integer): integer
                return x + y
            end

            function m.test(): integer
                return m.g(m.f())
            end
        ]], "function expects 3 argument(s) but received 2")
    end)

    it("detects too many arguments, when last argument is a function call", function()
        assert_error([[
            function m.f(): (integer, integer)
                return 1, 2
            end

            function m.g(x:integer): integer
                return x
            end

            function m.test(): integer
                return m.g(m.f())
            end
        ]], "function expects 1 argument(s) but received 2")
    end)

    it("detects wrong types of arguments to functions", function()
        assert_error([[
            function m.f(x: integer, y: integer): integer
                return x + y
            end

            function m.g(): integer
                return m.f(1.0, 2.0)
            end
        ]], "expected integer but found float in argument 1 of call to function")
    end)

    it("detects wrong types of arguments to builtin functions", function()
        assert_error([[
            function m.f()
                io.write(17)
            end
        ]], "expected string but found integer in argument 1")
    end)

    it("rejects void functions in expression contexts", function()
        assert_error([[
            local function f() end

            local function g()
                local x = 1 + f()
            end
        ]], "void instead of a number")
    end)

end)

--
-- Exp Verify
--


describe("Table constructor", function()

    describe("for arrrays", function()

        it("must not contain named fields", function()
            assert_error([[
                function m.fn()
                    local xs: {integer} = {10, 20, 30, x=17}
                end
            ]], "named field 'x' in array initializer")
        end)

        it("must contain the correct type", function()
            assert_error([[
                function m.fn()
                    local xs: {integer} = {10, "hello"}
                end
            ]], "expected integer but found string in array initializer")
        end)

    end)

    describe("for records", function()

        local function assert_record_error(code, expected_error)
            local program = util.render([[
                record Point
                    x: float
                    y: float
                end

                function m.f()
                    $code
                end
            ]], { code = code })

            assert_error(program, expected_error)
        end

        it("must not have an array part", function()
            assert_record_error([[
                local p: Point = { x = 10.0, y = 20.0, 30.0 }
            ]], "table initializer has array part")
        end)

        it("forbids initializing a field twice", function()
            assert_record_error([[
                local p: Point = { x = 10.0, x = 11.0, y = 20.0 }
            ]], "duplicate field 'x' in table initializer")
        end)

        it("forbids wrong field namer", function()
            assert_record_error([[
                local p: Point = { x = 10.0, y = 20.0, z = 30.0 }
            ]], "invalid field 'z' in table initializer")
        end)

        it("forbids missing fields in initializer", function()
            assert_record_error([[
                local p: Point = { y = 1.0 }
            ]],  "required field 'x' is missing")
        end)

        it("forbids wrong type in field", function()
            assert_record_error([[
                local p: Point = { x = 10.0, y = "hello" }
            ]],  "expected float but found string in table initializer")
        end)

    end)

    it("must have a compatible type hint", function()
        assert_error([[
            local p: string = { 10, 20, 30 }
        ]], "type hint for table initializer is not an array, table, or record type")
    end)

end)
