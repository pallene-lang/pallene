local c_compiler = require "titan-compiler.c_compiler"
local util = require "titan-compiler.util"

local function compile(titan_code)
    return function()
        local ok, errors =
            c_compiler.compile_titan_to_so("test.titan", titan_code, "test.so")
        assert(ok, errors[1])
    end
end

local function run_test(test_script)
    util.set_file_contents("test_script.lua", util.render([[
        local test = require "test"
        ${TEST_SCRIPT}
    ]], {
        TEST_SCRIPT = test_script
    }))
    local ok = os.execute("./lua/src/lua test_script.lua")
    os.execute("rm -f test_script.lua")
    assert.truthy(ok)
end

local function cleanup()
    os.execute("rm -f test.so")
end

describe("Titan coder /", function()
    teardown(cleanup)

    describe("Empty program /", function()
        setup(compile(""))

        it("compiles", function() end)
    end)

    describe("Exported functions /", function()
        setup(compile([[
            function f(): integer
                return 10
            end

            local function g(): integer
                return 11
            end
        ]]))

        it("does not export local functions", function()
            run_test([[
                assert(type(test.f) == "function")
                assert(type(test.g) == "nil")
            ]])
        end)
    end)

    describe("Function arguments /", function()
        setup(compile([[
            function id_int(x: integer): integer
                return x
            end

            function id_float(x: float): float
                return x
            end
        ]]))

        it("missing arguments", function()
            run_test([[
                local ok, err = pcall(test.id_int)
                assert(string.find(err,
                    "wrong number of arguments to function, " ..
                    "expected 1 but received 0",
                    nil, true))
            ]])
        end)

        it("too many arguments", function()
            run_test([[
                local ok, err = pcall(test.id_int, 10, 20)
                assert(string.find(err,
                    "wrong number of arguments to function, " ..
                    "expected 1 but received 2",
                    nil, true))
            ]])
        end)

        it("type of argument", function()
            run_test([[
                local ok, err = pcall(test.id_float, "abc")
                assert(string.find(err,
                    "wrong type for argument x at line 5, " ..
                    "expected float but found string",
                    nil, true))
            ]])
        end)

        -- See if error messages show float/integer instead of "number":
        it("expected float but found integer", function()
            run_test([[
                local ok, err = pcall(test.id_float, 10)
                assert(string.find(err,
                    "wrong type for argument x at line 5, " ..
                    "expected float but found integer",
                    nil, true))
            ]])
        end)

        it("expected float but found integer", function()
            run_test([[
                local ok, err = pcall(test.id_int, 3.14)
                assert(string.find(err,
                    "wrong type for argument x at line 1, " ..
                    "expected integer but found float",
                    nil, true))
            ]])
        end)
    end)

    describe("Literals /", function()
        setup(compile([[
            function f_nil(): nil
                return nil
            end

            function f_true(): boolean
                return true
            end

            function f_false(): boolean
                return false
            end

            function f_integer(): integer
                return 17
            end

            function f_float(): float
                return 3.14
            end

            function f_string(): string
                return "Hello World"
            end

            ------------

            function pi(): float
                return 3.141592653589793
            end

            function e(): float
                return 2.718281828459045
            end
        ]]))

        it("nil", function()
            run_test([[ assert(nil == test.f_nil()) ]])
        end)

        it("true", function()
            run_test([[ assert(true == test.f_true()) ]])
        end)

        it("false", function()
            run_test([[ assert(false == test.f_false()) ]])
        end)

        it("integer", function()
            run_test([[ assert(17 == test.f_integer()) ]])
        end)

        it("float", function()
            run_test([[ assert(3.14 == test.f_float()) ]])
        end)

        it("strings", function()
            run_test([[ assert("Hello World" == test.f_string()) ]])
        end)

        it("floating point literals are accurate", function()
            run_test([[
                local pi = 3.141592653589793
                local e  = 2.718281828459045
                assert(pi == test.pi())
                assert(e  == test.e())
                assert(pi*e*e == test.pi() * test.e() * test.e())
            ]])
        end)
    end)

    describe("Function calls /", function()
        setup(compile([[
            function f0(): integer
                return 17
            end

            function g0(): integer
                return f0()
            end

            -----------

            function f1(x:integer): integer
                return x
            end

            function g1(x:integer): integer
                return f1(x)
            end

            -----------

            function f2(x:integer, y:integer): integer
                return x+y
            end

            function g2(x:integer, y:integer): integer
                return f2(x, y)
            end

            -----------

            function gcd(a:integer, b:integer): integer
                if b == 0 then
                   return a
                else
                   return gcd(b, a % b)
                end
            end

            -----------

            local x = 10

            function incr_x(): ()
                x = x + 1
            end

            function next_x(): integer
                incr_x()
                return x
            end
        ]]))

        it("no parameters", function()
            run_test([[ assert(17 == test.g0()) ]])
        end)

        it("one parameter", function()
            run_test([[ assert(17 == test.g1(17)) ]])
        end)

        it("multiple parameters", function()
            run_test([[ assert(17 == test.g2(16, 1)) ]])
        end)

        it("recursive calls", function()
            run_test([[ assert(3*5 == test.gcd(2*3*5, 3*5*7)) ]])
        end)

        it("void functions", function()
            run_test([[ assert(11 == test.next_x()) ]])
        end)
    end)


    describe("Variables /", function()
        setup(compile([[
            function f_locals(): integer
                local a = 1
                local b = 1
                do
                    local a = 0
                    b = a
                end
                local c = a
                return 100*a + 10*b + c
             end

            local n = 0
            function f_globals(): integer
                n = n + 1
                return n
            end
        ]]))

               it("local variables", function()
            run_test([[ assert(101 == test.f_locals()) ]])
        end)

        it("global variables", function()
            run_test([[
                assert(1 == test.f_globals())
                assert(2 == test.f_globals())
                assert(3 == test.f_globals())
            ]])
        end)
    end)

    describe("Operators /", function()
        local titan_program_parts = {}
        local lua_tests = {}

        local function setup_unop(name, op, typ, rtyp)
            table.insert(titan_program_parts, util.render([[
                function $name (x: $typ): $rtyp
                    return $op x
                end
            ]], {
                name = name, typ = typ, rtyp = rtyp, op = op,
            }))

            lua_tests[name] = util.render([[
                local test_operators = require "test_operators"
                test_operators.check_unop(
                    $op_str,
                    function(x) return $op x end,
                    test.${name},
                    $typ_str
                )
            ]],{
                name = name,
                op = op,
                op_str = string.format("%q", op),
                typ_str = string.format("%q", typ),
            })
        end

        local function setup_binop(name, op, typ1, typ2, rtyp)
            table.insert(titan_program_parts, util.render([[
                function $name (x: $typ1, y:$typ2): $rtyp
                    return x ${op} y
                end
            ]], {
                name = name, typ1 = typ1, typ2=typ2, rtyp = rtyp, op = op,
            }))

            lua_tests[name] = util.render([[
                local test_operators = require "test_operators"
                test_operators.check_binop(
                    $op_str,
                    function(x, y) return (x $op y) end,
                    test.${name},
                    $typ1_str,
                    $typ2_str
                )
            ]],{
                name = name,
                op = op,
                op_str = string.format("%q", op),
                typ1_str = string.format("%q", typ1),
                typ2_str = string.format("%q", typ2),
            })
        end

        local function optest(name)
            run_test(lua_tests[name])
        end

        setup_unop("neg_int", "-",   "integer", "integer")
        setup_unop("bnot",    "~",   "integer", "integer")
        setup_unop("not_bool","not", "boolean", "boolean")

        setup_binop("add_int"       , "+", "integer", "integer", "integer")
        setup_binop("add_float"     , "+", "float", "float", "float")
        setup_binop("sub_int"       , "-", "integer", "integer", "integer")
        setup_binop("sub_float"     , "-", "float", "float", "float")
        setup_binop("mul_int"       , "*", "integer", "integer", "integer")
        setup_binop("mul_float"     , "*", "float", "float", "float")
        setup_binop("floatdiv_int"  , "/", "integer", "integer", "float")
        setup_binop("floatdiv_float", "/", "float", "float", "float")
        setup_binop("band"          , "&", "integer", "integer", "integer")
        setup_binop("bor"           , "|", "integer", "integer", "integer")
        setup_binop("bxor"          , "~", "integer", "integer", "integer")
        setup_binop("lshift"        , "<<", "integer", "integer", "integer")
        setup_binop("rshift"        , ">>", "integer", "integer", "integer")
        setup_binop("mod_int"       , "%", "integer", "integer", "integer")
        setup_binop("intdiv_int"    , "//", "integer", "integer", "integer")
        setup_binop("intdiv_float"  , "//", "float", "float", "float")
        setup_binop("pow_float"     , "^", "float", "float", "float")
        setup_binop("eq_int"        , "==", "integer", "integer", "boolean")
        setup_binop("neq_int"       , "~=", "integer", "integer", "boolean")
        setup_binop("lt_int"        , "<", "integer", "integer", "boolean")
        setup_binop("gt_int"        , ">", "integer", "integer", "boolean")
        setup_binop("le_int"        , "<=", "integer", "integer", "boolean")
        setup_binop("ge_int"        , ">=", "integer", "integer", "boolean")
        setup_binop("and_bool"      , "and", "boolean", "boolean", "boolean")
        setup_binop("or_bool"       , "or", "boolean", "boolean", "boolean")

        setup(compile(table.concat(titan_program_parts, "\n")))

        it("integer unary (-)",  function() optest("neg_int") end)
        it("integer unary (~)",  function() optest("bnot") end)
        it("boolean (not)",      function() optest("not_bool") end)

        it("integer (+)",        function() optest("add_int") end)
        it("float (+)",          function() optest("add_float") end)
        it("integer (-)",        function() optest("sub_int")  end)
        it("float (-)",          function() optest("sub_float")  end)
        it("integer (*)",        function() optest("mul_int")  end)
        it("float (*)",          function() optest("mul_float") end)
        it("integer (/)",        function() optest("floatdiv_int") end)
        it("float (/)",          function() optest("floatdiv_float") end)
        it("binary and (&)",     function() optest("band") end)
        it("binary or (|)",      function() optest("bor") end)
        it("binary xor (~)",     function() optest("bxor") end)
        it("left shift (<<)",    function() optest("lshift")  end)
        it("right shift (>>)",   function() optest("rshift") end)
        it("integer (%)",        function() optest("mod_int") end)
        it("integer (//)",       function() optest("intdiv_int") end)
        it("float (//)",         function() optest("intdiv_float") end)
        it("float (^)",          function() optest("pow_float") end)
        it("integer (==)",       function() optest("eq_int") end)
        it("integer (~=)",       function() optest("neq_int") end)
        it("integer (<)",        function() optest("lt_int") end)
        it("integer (>)",        function() optest("gt_int") end)
        it("integer (<=)",       function() optest("le_int") end)
        it("integer (>=)",       function() optest("ge_int") end)
        it("boolean (and)",      function() optest("and_bool") end)
        it("boolean (or)",       function() optest("or_bool") end)
    end)

    describe("Statements /", function()
        setup(compile([[
            function stat_blocks(): integer
                local a = 1
                local b = 2
                do
                    local a = 3
                    b = a
                    a = b + 1
                end
                return a + b
            end

            function sign(x: integer) : integer
                if x < 0 then
                    return -1
                elseif x == 0 then
                    return 0
                else
                    return 1
                end
            end

            function abs(x: integer) : integer
                if x >= 0 then
                    return x
                end
                return -x
            end

            function factorial_while(n: integer): integer
                local r = 1
                while n > 0 do
                    r = r * n
                    n = n - 1
                end
                return r
            end

            function factorial_int_for_inc(n: integer): integer
                local res = 1
                for i = 1, n do
                    res = res * i
                end
                return res
            end

            function factorial_int_for_dec(n: integer): integer
                local res = 1
                for i = n, 1, -1 do
                    res = res * i
                end
                return res
            end

            function factorial_float_for_inc(n: float): float
                local res = 1.0
                for i = 1.0, n do
                    res = res * i
                end
                return res
            end

            function factorial_float_for_dec(n: float): float
                local res = 1.0
                for i = n, 1.0, -1.0 do
                    res = res * i
                end
                return res
            end

            --------------------

            local i = 0

            function next(): integer
                i = i + 1
                return i
            end

            function stat_call(): integer
                next()
                return next()
            end
        ]]))

        it("Block, Assign, Decl", function()
            run_test([[ assert(4 == test.stat_blocks()) ]])
        end)

        it("If statement (with else)", function()
            run_test([[ assert(-1 == test.sign(-10)) ]])
            run_test([[ assert( 0 == test.sign(  0)) ]])
            run_test([[ assert( 1 == test.sign( 10)) ]])
        end)

        it("If statement (without else)", function()
            run_test([[ assert(10 == test.abs(-10)) ]])
            run_test([[ assert( 0 == test.abs(  0)) ]])
            run_test([[ assert(10 == test.abs( 10)) ]])
        end)

        it("While", function()
            run_test([[ assert(720 == test.factorial_while(6)) ]])
        end)

        it("For loop (integer) (going up)", function()
            run_test([[ assert(720 == test.factorial_int_for_inc(6)) ]])
        end)

        it("For loop (integer) (going down)", function()
            run_test([[ assert(720 == test.factorial_int_for_dec(6)) ]])
        end)

        it("For loop (float) (going up)", function()
            run_test([[ assert(720.0 == test.factorial_float_for_inc(6.0)) ]])
        end)

        it("For loop (float) (going down)", function()
            run_test([[ assert(720.0 == test.factorial_float_for_dec(6.0)) ]])
        end)

        it("Call", function()
            run_test([[ assert(2 == test.stat_call()) ]])
        end)
    end)

    describe("Arrays /", function()
        setup(compile([[
            function newarr(): {integer}
                return {10,20,30}
            end

            function len(xs:{integer}): integer
                return #xs
            end

            function get(arr: {integer}, i: integer): integer
                return arr[i]
            end

            function set(arr: {integer}, i: integer, v: integer)
                arr[i] = v
            end

            function insert(xs: {integer}, v:integer): ()
                table_insert(xs, v)
            end

            function remove(xs: {integer}): ()
                table_remove(xs)
            end
        ]]))

        it("literals", function()
            run_test([[
                local t = test.newarr()
                assert(type(t) == "table")
                assert(#t == 3)
                assert(10 == t[1])
                assert(20 == t[2])
                assert(30 == t[3])
            ]])
        end)

        it("length operator (#)", function()
            run_test([[
                assert(0 == test.len({}))
                assert(1 == test.len({10}))
                assert(2 == test.len({10, 20}))
            ]])
        end)

        it("get", function()
            run_test([[
                local arr = {10, 20, 30}
                assert(10 == test.get(arr, 1))
                assert(20 == test.get(arr, 2))
                assert(30 == test.get(arr, 3))
            ]])
        end)

        it("set", function()
            run_test( [[
                local arr = {10, 20, 30}
                test.set(arr, 2, 123)
                assert( 10 == arr[1])
                assert(123 == arr[2])
                assert( 30 == arr[3])
            ]])
        end)

        it("check out of bounds errors in get", function()
            run_test([[
                local arr = {10, 20, 30}

                local ok, err = pcall(test.get, arr, 0)
                assert(not ok)
                assert(string.find(err, "out of bounds", nil, true))

                local ok, err = pcall(test.get, arr, 4)
                assert(not ok)
                assert(string.find(err, "out of bounds", nil, true))

                table.remove(arr)
                local ok, err = pcall(test.get, arr, 3)
                assert(not ok)
                assert(string.find(err, "out of bounds", nil, true))
            ]])
        end)

        it("check out of bounds errors in set", function()
            run_test([[
                local arr = {10, 20, 30}

                local ok, err = pcall(test.set, arr, 0, 123)
                assert(not ok)
                assert(string.find(err, "out of bounds", nil, true))

                local ok, err = pcall(test.set, arr, 4, 123)
                assert(not ok)
                assert(string.find(err, "out of bounds", nil, true))

                table.remove(arr)
                local ok, err = pcall(test.set, arr, 3, 123)
                assert(not ok)
                assert(string.find(err, "out of bounds", nil, true))
            ]])
        end)

        it("checks type tags in get", function()
            run_test([[
                local arr = {10, 20, "hello"}

                local ok, err = pcall(test.get, arr, 3)
                assert(not ok)
                assert(
                    string.find(err, "wrong type for array element", nil, true))
            ]])
        end)

        it("checks type tags in set", function()
            run_test([[
                local arr = {10, 20, "hello"}

                local ok, err = pcall(test.set, arr, 3, 20)
                assert(not ok)
                assert(
                    string.find(err, "wrong type for array element", nil, true))
            ]])
        end)

        it("insert", function()
            run_test([[
                local arr = {}
                for i = 1, 50 do
                    test.insert(arr, 10*i)
                    assert(i == #arr)
                    for j = 1, i do
                        assert(10*j == arr[j])
                    end
                end
            ]])
        end)

        it("remove", function()
            run_test([[
                local arr = {}
                for i = 1, 100 do
                    arr[i] = 10*i
                end
                for i = 99, 50, -1 do
                    test.remove(arr)
                    assert(i == #arr)
                    for j = 1, i do
                        assert(10*j == arr[j])
                    end
                end
            ]])
        end)
    end)

    describe("First class functions /", function()
        setup(compile([[
            function inc(x:integer): integer
                return x + 1
            end

            function dec(x:integer): integer
                return x - 1
            end

            local f: integer->integer = inc

            function setf(g:integer->integer): ()
                f = g
            end

            function getf(): integer->integer
                return f
            end

            function callf(x:integer): integer
                return f(x)
            end

            --------

            function call(
                f : integer -> integer,
                x : integer
            ) :  integer
                return f(x)
            end
        ]]))

        it("Object identity", function()
            run_test([[
                assert(test.getf() == test.getf())
            ]])
        end)

        it("Can get and set global function vars", function()
            run_test([[
                assert(11 == test.getf()(10))
                test.setf(test.dec)
                assert( 9 == test.getf()(10))
            ]])
        end)

        it("Can call global function vars", function()
            run_test([[
                assert(11 == test.callf(10))
            ]])
        end)

        it("Can call Lua functions", function()
            run_test([[
                local f = function(x) return x * 20 end
                assert(200 == test.call(f, 10))
            ]])
        end)
    end)

    describe("Strings", function()
        setup(compile([[
            function len(s:string): integer
                return #s
            end
        ]]))

        it("length operator (#)", function()
            run_test([[ assert( 0 == test.len("")) ]])
            run_test([[ assert( 1 == test.len("H")) ]])
            run_test([[ assert(11 == test.len("Hello World")) ]])
        end)
    end)

    describe("Records", function()
        setup(compile([[
            record Foo
                x: integer
                y: {integer}
            end

            function make_foo(x: integer, y: {integer}): Foo
                return { x = x, y = y }
            end

            function get_x(foo: Foo): integer
                return foo.x
            end

            function set_x(foo: Foo, x: integer)
                foo.x = x
            end

            function get_y(foo: Foo): {integer}
                return foo.y
            end

            function set_y(foo: Foo, y: {integer})
                foo.y = y
            end

            record Prim
                x: integer
            end

            function make_prim(x: integer): Prim
                return { x = x }
            end

            record Gc
                x: {integer}
            end

            function make_gc(x: {integer}): Gc
                return { x = x }
            end
        ]]))

        it("can create records", function()
            run_test([[
                local foo = test.make_foo(123, {})
                assert("userdata" == type(foo))
            ]])
        end)

        it("can get/set primitive fields in titan", function()
            run_test([[
                local foo = test.make_foo(123, {})
                assert(123 == test.get_x(foo))
                test.set_x(foo, 456)
                assert(456 == test.get_x(foo))
            ]])
        end)

        it("can get/set gc fields in titan", function()
            run_test([[
                local a = {}
                local b = {}
                local foo = test.make_foo(123, a)
                assert(a == test.get_y(foo))
                test.set_y(foo, b)
                assert(b == test.get_y(foo))
            ]])
        end)

        it("can create records with only primitive fields", function()
            run_test([[
                local x = test.make_prim(123)
                assert("userdata" == type(x))
            ]])
        end)

        it("can create records with only gc fields", function()
            run_test([[
                local x = test.make_gc({})
                assert("userdata" == type(x))
            ]])
        end)
    end)
end)
