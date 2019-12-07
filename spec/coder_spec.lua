local driver = require "pallene.driver"
local util = require "pallene.util"

local function compile(pallene_code)
    return function()
        assert(util.set_file_contents("test.pln", pallene_code))
        local ok, errors =
            driver.compile("pallenec-tests", "pln", "so", "test.pln")
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
    assert(util.execute("./lua/src/lua test_script.lua > test_output.txt"))
end

local function assert_test_output(expected)
    local output = assert(util.get_file_contents("test_output.txt"))
    assert.are.same(expected, output)
end

local function cleanup()
    os.remove("test.pln")
    os.remove("test.so")
    os.remove("test_script.lua")
    os.remove("test_output.txt")
end

describe("Pallene coder /", function()
    teardown(cleanup)

    describe("Empty program /", function()
        setup(compile(""))

        it("compiles", function() end)
    end)

    describe("Exported functions /", function()
        setup(compile([[
                  function f(): integer return 10 end
            local function g(): integer return 11 end
        ]]))

        it("does not export local functions", function()
            run_test([[
                assert(type(test.f) == "function")
                assert(type(test.g) == "nil")
            ]])
        end)
    end)

    describe("Literals /", function()
        setup(compile([[
            function f_nil(): nil          return nil  end
            function f_true(): boolean     return true end
            function f_false(): boolean    return false end
            function f_integer(): integer  return 17 end
            function f_float(): float      return 3.14 end
            function f_string(): string    return "Hello World" end
            function pi(): float           return 3.141592653589793 end
            function e(): float            return 2.718281828459045 end
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

    describe("Variables /", function()
        setup(compile([[
            function fst(x:integer, y:integer): integer return x end
            function snd(x:integer, y:integer): integer return y end

            local n = 0
            function next_n(): integer
                n = n + 1
                return n
            end
        ]]))

        it("local variables", function()
            run_test([[
                assert(10 == test.fst(10, 20))
                assert(20 == test.snd(10, 20))
            ]])
        end)

        it("global variables", function()
            run_test([[
                assert(1 == test.next_n())
                assert(2 == test.next_n())
                assert(3 == test.next_n())
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

            function skip_a() end
            function skip_b() skip_a(); skip_a() end
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
            run_test([[ assert(0 == select("#", test.skip_b())) ]])
        end)

        -- Errors

        it("missing arguments", function()
            run_test([[
                local ok, err = pcall(test.g1)
                assert(string.find(err,
                    "wrong number of arguments to function 'g1', " ..
                    "expected 1 but received 0",
                    nil, true))
            ]])
        end)

        it("too many arguments", function()
            run_test([[
                local ok, err = pcall(test.g1, 10, 20)
                assert(string.find(err,
                    "wrong number of arguments to function 'g1', " ..
                    "expected 1 but received 2",
                    nil, true))
            ]])
        end)

        it("type of argument", function()
            -- Also sees if error messages say "float" and "integer"
            -- instead of "number"
            run_test([[
                local ok, err = pcall(test.g1, 3.14)
                assert(string.find(err,
                    "wrong type for argument x, " ..
                    "expected integer but found float",
                    nil, true))
            ]])
        end)
    end)

    describe("First class functions /", function()
        setup(compile([[
            function inc(x:integer): integer   return x + 1   end
            function dec(x:integer): integer   return x - 1   end

            function get_inc(): integer->integer
                return inc
            end

            --------

            function call(
                f : integer -> integer,
                x : integer
            ) :  integer
                return f(x)
            end

            --------

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
        ]]))

        it("Object identity", function()
            run_test([[
                assert(test.inc == test.get_inc())
            ]])
        end)

        it("Can call non-static functions", function()
            run_test([[
                local f = function(x) return x * 20 end
                assert(200 == test.call(f, 10))
                assert(201 == test.call(test.inc, 200))
            ]])
        end)

        it("Can call global function vars", function()
            run_test([[
                assert(11 == test.callf(10))
            ]])
        end)

        it("Can get, set, and call global function vars", function()
            run_test([[
                assert(11 == test.getf()(10))
                test.setf(test.dec)
                assert( 9 == test.getf()(10))
            ]])
        end)
    end)

    describe("Unary Operators /", function()

        local tests = {
            { "neg_i", "-",   "integer", "integer" },
            { "bnot",  "~",   "integer", "integer" },
            { "not_b", "not", "boolean", "boolean" },
        }

        local pallene_code = {}
        local test_scripts = {}

        for i, test in ipairs(tests) do
            local name, op, typ, rtyp = test[1], test[2], test[3], test[4]

            pallene_code[i] = util.render([[
                function $name (x: $typ): $rtyp
                    return $op x
                end
            ]], {
                name = name, typ = typ, rtyp = rtyp, op = op,
            })

            test_scripts[name] = util.render([[
                local test_op = require "spec.coder_test_operators"
                test_op.check_unop(
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

        setup(compile(table.concat(pallene_code, "\n")))

        for _, test in ipairs(tests) do
            local name = test[1]
            it(name, function() run_test(test_scripts[name]) end)
        end
    end)

    describe("Binary Operators /", function()

        local tests = {
            { "add_ii",    "+",   "integer", "integer", "integer" },
            { "add_if",    "+",   "integer", "float",   "float" },
            { "add_fi",    "+",   "float",   "integer", "float" },
            { "add_ff",    "+",   "float",   "float",   "float" },

            { "sub_ii",    "-",   "integer", "integer", "integer" },
            { "sub_if",    "-",   "integer", "float",   "float" },
            { "sub_fi",    "-",   "float",   "integer", "float" },
            { "sub_ff",    "-",   "float",   "float",   "float" },

            { "mul_ii",    "*",   "integer", "integer", "integer" },
            { "mul_if",    "*",   "integer", "float",   "float" },
            { "mul_fi",    "*",   "float",   "integer", "float" },
            { "mul_ff",    "*",   "float",   "float",   "float" },

            { "mod_ii",    "%",   "integer", "integer", "integer" },
            -- NYI { "mod_if",    "%",   "integer", "float",   "float" },
            -- NYI { "mod_fi",    "%",   "float",   "integer", "float" },
            -- NYI { "mod_ff",    "%",   "float",   "float",   "float" },

            { "fltdiv_ii", "/",   "integer", "integer", "float" },
            { "fltdiv_ff", "/",   "float",   "float",   "float" },

            { "band",      "&",   "integer", "integer", "integer" },
            { "bor",       "|",   "integer", "integer", "integer" },
            { "bxor",      "~",   "integer", "integer", "integer" },

            { "lshift",    "<<",  "integer", "integer", "integer" },
            { "rshift",    ">>",  "integer", "integer", "integer" },

            { "intdiv_ii", "//",  "integer", "integer", "integer" },
            { "intdiv_if", "//",  "integer", "float",   "float" },
            { "intdiv_fi", "//",  "float",   "integer", "float" },
            { "intdiv_ff", "//",  "float",   "float",   "float" },

            { "pow_ii",    "^",   "integer", "integer", "float" },
            { "pow_ff",    "^",   "float",   "float",   "float" },

            { "eq_ii",     "==",  "integer", "integer", "boolean" },
            { "ne_ii",     "~=",  "integer", "integer", "boolean" },
            { "lt_ii",     "<",   "integer", "integer", "boolean" },
            { "gt_ii",     ">",   "integer", "integer", "boolean" },
            { "le_ii",     "<=",  "integer", "integer", "boolean" },
            { "ge_ii",     ">=",  "integer", "integer", "boolean" },

            { "eq_ff",     "==",  "float",   "float",   "boolean" },
            { "ne_ff",     "~=",  "float",   "float",   "boolean" },
            { "lt_ff",     "<",   "float",   "float",   "boolean" },
            { "gt_ff",     ">",   "float",   "float",   "boolean" },
            { "le_ff",     "<=",  "float",   "float",   "boolean" },
            { "ge_ff",     ">=",  "float",   "float",   "boolean" },

            { "eq_ss",     "==",  "string",  "string",  "boolean" },
            { "ne_ss",     "~=",  "string",  "string",  "boolean" },
            { "lt_ss",     "<",   "string",  "string",  "boolean" },
            { "gt_ss",     ">",   "string",  "string",  "boolean" },
            { "le_ss",     "<=",  "string",  "string",  "boolean" },
            { "ge_ss",     ">=",  "string",  "string",  "boolean" },

            { "eq_bb",     "==",  "boolean",   "boolean",   "boolean" },
            { "ne_bb",     "~=",  "boolean",   "boolean",   "boolean" },

            { "and_bb",    "and", "boolean", "boolean", "boolean" },
            { "or_bb",     "or",  "boolean", "boolean", "boolean" },

            { "concat_ss", "..",  "string",  "string",  "string" },
        }

        local pallene_code = {}
        local test_scripts = {}

        for i, test in ipairs(tests) do
            local name, op, typ1, typ2, rtyp =
                test[1], test[2], test[3], test[4], test[5]

            pallene_code[i] = util.render([[
                function $name (x: $typ1, y:$typ2): $rtyp
                    return x ${op} y
                end
            ]], {
                name = name, typ1 = typ1, typ2=typ2, rtyp = rtyp, op = op,
            })

            test_scripts[name] = util.render([[
                local test_op = require "spec.coder_test_operators"
                test_op.check_binop(
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

        setup(compile(table.concat(pallene_code, "\n")))

        for _, test in ipairs(tests) do
             local name = test[1]
             it(name, function() run_test(test_scripts[name]) end)
        end
    end)

    describe("Coercions with dynamic type /", function()

        local tests = {
            { "boolean"  , "boolean",         "true"},
            { "integer"  , "integer",         "17"},
            { "float"    , "float",           "3.14"},
            { "string"   , "string",          "'hello'"},
            { "function" , "integer->string", "tostring"},
            { "array"    , "{integer}",       "{10,20}"},
            { "record"   , "Empty",           "test.new_empty()"},
            { "value"    , "value",           "17"},
        }

        local record_decls = [[
            record Empty
            end
            function new_empty(): Empty
                return {}
            end
        ]]

        local pallene_code = {}
        local test_to      = {}
        local test_from    = {}

        for i, test in pairs(tests) do
            local name, typ, value = test[1], test[2], test[3]

            pallene_code[i] = util.render([[
                function from_${name}(x: ${typ}): value
                    return (x as value)
                end
                function to_${name}(x: value): ${typ}
                    return (x as ${typ})
                end
            ]], {
                name = name,
                typ = typ,
            })

            test_to[name] = util.render([[
                local x = ${value}
                assert(x == test.from_${name}(x))
            ]], {
                name = name,
                value = value
            })

            test_from[name] = util.render([[
                local x = ${value}
                assert(x == test.from_${name}(x))
            ]], {
                name = name,
                value = value
            })
        end

        setup(compile(
            record_decls .. "\n" ..
            table.concat(pallene_code, "\n")
        ))

        for _, test in ipairs(tests) do
            local name = test[1]
            it(name .. "->value", function() run_test(test_to[name]) end)
        end

        for _, test in ipairs(tests) do
            local name = test[1]
            it("value->" .. name, function() run_test(test_from[name]) end)
        end

        it("detects downcast error", function()
            run_test([[
                local ok, err = pcall(test.to_integer, "hello")
                assert(not ok)
                assert(string.find(err,
                    "wrong type for downcasted value", nil, true))
            ]])
        end)
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

            function repeat_until(): integer
                local x = 0
                repeat
                    x = x + 1
                    local limit = x * 10
                until limit >= 100
                return x
            end

            function break_while() : integer
                while true do break end
                return 17
            end

            function break_repeat() : integer
                repeat break until false
                return 17
            end

            function break_for(): integer
                local x = 0
                for i = 1, 10 do
                    x = x + i
                    break
                end
                return x
            end

            function nested_break(x:boolean): integer
                while true do
                    while true do
                        break
                        return 10
                    end
                    if x then
                        break
                        return 20
                    else
                        return 30
                    end
                end
                return 40
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

        it("Repeat until", function()
            run_test([[ assert(10 == test.repeat_until()) ]])
        end)

        it("Break while loop", function()
            run_test([[ assert(17 == test.break_while()) ]])
        end)

        it("Break repeat-until loop", function()
            run_test([[ assert(17 == test.break_repeat()) ]])
        end)

        it("Break for loop", function()
            run_test([[ assert(1 == test.break_for()) ]])
        end)
        it("Nested break", function()
            run_test([[ assert(40 == test.nested_break(true)) ]])
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

            function geti(arr: {integer}, i: integer): integer
                return arr[i]
            end

            function seti(arr: {integer}, i: integer, v: integer)
                arr[i] = v
            end

            function insert(xs: {value}, v:value): ()
                xs[#xs + 1] = v
            end

            function remove(xs: {value}): ()
                xs[#xs] = nil
            end

            function getvalue(xs: {value}, i:integer): value
                return xs[i]
            end

            function getnil(xs: {nil}, i: integer): nil
                return xs[i]
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
                assert(10 == test.geti(arr, 1))
                assert(20 == test.geti(arr, 2))
                assert(30 == test.geti(arr, 3))
            ]])
        end)

        it("set", function()
            run_test( [[
                local arr = {10, 20, 30}
                test.seti(arr, 2, 123)
                assert( 10 == arr[1])
                assert(123 == arr[2])
                assert( 30 == arr[3])
            ]])
        end)

        it("checks type tags in get", function()
            run_test([[
                local arr = {10, 20, "hello"}

                local ok, err = pcall(test.geti, arr, 3)
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

        it("out-of bounds get is a tag error", function()
            run_test([[
                local arr = {10, 20, 30}

                local ok, err = pcall(test.geti, arr, 0)
                assert(not ok)
                assert(string.find(err, "invalid index", nil, true))

                local ok, err = pcall(test.geti, arr, 4)
                assert(not ok)
                assert(string.find(err, "wrong type for array element", nil, true))

                table.remove(arr)
                local ok, err = pcall(test.geti, arr, 3)
                assert(not ok)
                assert(string.find(err, "wrong type for array element", nil, true))
            ]])
        end)

        it("{nil}: in-bounds get nil", function()
            run_test([[ assert(nil == test.getnil({10, nil, 30}, 2)) ]])
        end)

        it("{nil}: out-of-bounds get nil", function()
            run_test([[ assert(nil == test.getnil({10, nil, 30}, 4)) ]])
        end)

        it("{value}: get non-nil", function()
            run_test([[ assert(10  == test.getvalue({10, nil, 30}, 1)) ]])
        end)

        it("{value}: in-bounds get nil", function()
            run_test([[ assert(nil == test.getvalue({10, nil, 30}, 2)) ]])
        end)

        it("{value}: out-of-bounds get nil", function()
            run_test([[ assert(nil == test.getvalue({10, nil, 30}, 4)) ]])
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

    describe("Typealias", function()
        setup(compile([[
            type Float = float
            type FLOAT = float

            function Float2float(x: Float): float return x end
            function float2Float(x: float): Float return x end
            function Float2FLOAT(x: Float): FLOAT return x end

            record point
                x: Float
            end

            type Point = point
            type Points = {Point}

            function newPoint(x: Float): Point
                return {x = x}
            end

            function get(p: Point): FLOAT
                return p.x
            end

            function addPoint(ps: Points, p: Point)
                ps[#ps + 1] = p
            end
        ]]))

        it("converts between typealiases of the same type", function()
            run_test([[
                assert(1.1 == test.Float2float(1.1))
                assert(1.1 == test.float2Float(1.1))
                assert(1.1 == test.Float2FLOAT(1.1))
            ]])
        end)

        it("creates a records with typealiases", function()
            run_test([[
                local p = test.newPoint(1.1)
                assert(1.1 == test.get(p))
            ]])
        end)

        it("manipulates typealias of an array", function()
            run_test([[
                local p = test.newPoint(1.1)
                local ps = {}
                test.addPoint(ps, p)
                assert(p == ps[1])
            ]])
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

            record Empty
            end

            function make_empty(): Empty
                return {}
            end
        ]]))

        it("create records", function()
            run_test([[
                local foo = test.make_foo(123, {})
                assert("userdata" == type(foo))
            ]])
        end)

        it("get/set primitive fields in pallene", function()
            run_test([[
                local foo = test.make_foo(123, {})
                assert(123 == test.get_x(foo))
                test.set_x(foo, 456)
                assert(456 == test.get_x(foo))
            ]])
        end)

        it("get/set gc fields in pallene", function()
            run_test([[
                local a = {}
                local b = {}
                local foo = test.make_foo(123, a)
                assert(a == test.get_y(foo))
                test.set_y(foo, b)
                assert(b == test.get_y(foo))
            ]])
        end)

        it("create records with only primitive fields", function()
            run_test([[
                local x = test.make_prim(123)
                assert("userdata" == type(x))
            ]])
        end)

        it("create records with only gc fields", function()
            run_test([[
                local x = test.make_gc({})
                assert("userdata" == type(x))
            ]])
        end)

        it("create empty records", function()
            run_test([[
                local x = test.make_empty()
                assert("userdata" == type(x))
            ]])
        end)

        it("protect record metatables", function()
            run_test([[
                local x = test.make_prim(123)
                assert(getmetatable(x) == false)
            ]])
        end)

        it("check record tags", function()
            -- TODO: change this message to mention the relevant record types
            -- instead of only saying "userdata"
            run_test([[
                local prim = test.make_prim(123)
                local ok, err = pcall(test.get_x, prim)
                assert(not ok)
                assert(string.find(err, "expected userdata but found userdata",
                        nil, true))
            ]])
        end)
    end)

    describe("I/O", function()
        setup(compile([[
            function write(s:string)
                io_write(s)
            end
        ]]))

        it("io.write works", function()
            run_test([[
                test.write("Hello:)World")
            ]])
            assert_test_output("Hello:)World")
        end)
    end)

    describe("tofloat builtin", function()
        setup(compile([[
            function itof(x:integer): float
                return tofloat(x)
            end
        ]]))

        it("works", function()
            run_test([[
                local x_i = 1
                local x_f = test.itof(x_i)
                assert("float" == math.type(x_f))
                assert(1.0 == x_f)
            ]])
        end)
    end)

    describe("math.sqrt builtin", function()
        setup(compile([[
            function square_root(x: float): float
                return math_sqrt(x)
            end
        ]]))

        it("works on positive numbers", function()
            run_test([[
                assert(1.0 == test.square_root(1.0))
                assert(2.0 == test.square_root(4.0))
                assert(3.0 == test.square_root(9.0))
                assert(4.0 == test.square_root(16.0))
                assert(math.huge == test.square_root(math.huge))
            ]])
        end)

        it("returns NaN on negative numbers", function()
            run_test([[
                local x = test.square_root(-4.0)
                assert(x ~= x)
            ]])
        end)

        it("returns NaN on NaN", function()
            run_test([[
                local x = test.square_root(0.0 / 0.0)
                assert(x ~= x)
            ]])
        end)
    end)

    describe("string.char builtin", function()
        setup(compile([[
            function chr(x: integer): string
                return string_char(x)
            end
        ]]))

        it("works on normal characters", function()
            run_test([[
                for i = 1, 255 do
                    assert(string.char(i) == test.chr(i))
                end
            ]])
        end)

        it("works on zero", function()
            run_test([[
                assert(string.char(0) == test.chr(0))
            ]])
        end)

        it("error case", function()
            run_test([[
                local ok, err = pcall(test.chr, -1)
                assert(not ok)
                assert(string.find(err, "out of range", nil, true))

                local ok, err = pcall(test.chr, 256)
                assert(not ok)
                assert(string.find(err, "out of range", nil, true))
            ]])
        end)
    end)

    describe("string.sub builtin", function()
        setup(compile([[
            function sub(s: string, i: integer, j: integer): string
                return string_sub(s, i, j)
            end
        ]]))

        it("work", function()
            run_test([[
                local s = "abcde"
                for i = -10, 10 do
                    for j = -10, 10 do
                        assert(string.sub(s, i, j) == test.sub(s, i, j))
                    end
                end
            ]])
        end)
    end)

    describe("value", function()
        setup(compile([[
            function id(x:value): value
                return x
            end

            function call(f:value->value, x:value): value
                return f(x)
            end

            function read(xs:{value}, i:integer): value
                return xs[i]
            end

            function write(xs:{value}, i:integer, x:value): ()
                xs[i] = x
            end
        ]]))

        --
        -- All of these have a separate branch for the Value and the non-Value
        -- case. So we better stress them by testing the Value case...
        --

        it("can receive and return values", function()
            run_test([[ assert(17 == test.id(17)) ]])
            run_test([[ assert(true == test.id(true)) ]])
            run_test([[ assert(true == test.call(test.id, true)) ]])
        end)

        it("can read from array of value", function()
            run_test([[
                local xs = {10, "hello"}
                assert(10 == test.read(xs, 1))
                assert("hello" == test.read(xs, 2))
            ]])
        end)

        it("can write to array of value", function()
            run_test([[
                local xs = {}
                test.write(xs, 1, 10)
                test.write(xs, 2, "hello")
                assert(10 == xs[1])
                assert("hello" == xs[2])
            ]])
        end)
    end)

    describe("Corner cases of scoping", function()

        setup(compile([[
            record Point
                x: integer
                y: integer
            end

            local x = 10

            type y = integer

            ------

            function local_type(): integer
                local Point: Point = { x=1, y=2 }
                return Point.x
            end

            function local_initializer(): integer
                local x = x + 1
                return x
            end

            function for_type_annotation(): integer
                local res = 0
                for y:y = 1, 10 do
                    res = res + y
                end
                return res
            end

            function for_initializer(): integer
                local res = 0
                for x = x + 1, x + 100, x-7 do
                    res = res + 1
                end
                return res
            end

            function tofloat_shadowing(x:integer) : float
                local tofloat = 1.0
                return (x + tofloat)
            end
        ]]))

        it("local variable doesn't shadow its type annotation", function()
            run_test([[ assert( 1 == test.local_type() ) ]])
        end)

        it("local variable scope doesn't shadow its initializer", function()
            run_test([[ assert( 11 == test.local_initializer() ) ]])
        end)

        it("for loop variable scope doesn't shadow its type annotation", function()
            run_test([[ assert( 55 == test.for_type_annotation() ) ]])
        end)

        it("for loop variable scope doesn't shadow its initializers", function()
            run_test([[ assert( 34 == test.for_initializer() ) ]])
        end)

        it("tofloat in coercions doesn't get shadowed", function()
            run_test([[ assert( 21.0 == test.tofloat_shadowing(20) ) ]])
        end)
    end)

    describe("Non-constant toplevel initializers", function()
        setup(compile([[
            function f(): integer
                return 10
            end

            local x1 = f()
            local x2 = x1
            local x3 = -x2
            local x4 : {integer} = { x1 }

            function get_x1(): integer
                return x1
            end

            function get_x2(): integer
                return x2
            end

            function get_x3(): integer
                return x3
            end

            function get_x4(): {integer}
                return x4
            end
        ]]))

        it("", function()
            run_test([[
                assert(  10 == test.get_x1() )
                assert(  10 == test.get_x2() )
                assert( -10 == test.get_x3() )
                local x4 = test.get_x4()
                assert ( 1 == #x4 )
                assert ( 10 == x4[1] )
            ]])
        end)
    end)

    describe("Nested for loops", function()
        setup(compile([[
            function mul(n: integer, m:integer) : integer
                local ret = 0
                for i = 1, n do
                    for j = 1, m do
                        ret = ret + 1
                    end
                end
                return ret
            end
        ]]))

        it("", function()
            run_test([[
                assert( 0 == test.mul(0, 2))
                assert( 0 == test.mul(2, 0))
                assert(15 == test.mul(3, 5))
            ]])
        end)
    end)

    describe("Constant propagation", function()
        setup(compile([[
            local x = 0 -- never read from
            local step = 1
            local counter = 0

            local function inc(): integer
                counter = counter + step
                return counter
            end

            function next(): integer
                x = inc()
                return counter
            end
        ]]))

        it("preserves assignment side-effects", function()
            run_test([[
                assert(1 == test.next())
                assert(2 == test.next())
                assert(3 == test.next())
            ]])
        end)
    end)

    describe("Uninitialized variables", function()
        setup(compile([[
            function sign(x: integer): integer
                local ret: integer
                if     x  < 0 then
                    ret = -1
                elseif x == 0 then
                    ret = 0
                else
                    ret = 1
                end
                return ret
            end

            function non_breaking_loop(): integer
                local i = 1
                while true do
                    if i == 42 then return i end
                    i = i + 1
                end
            end

            function initialize_inside_loop(): integer
                local x: integer
                repeat
                    x = 17
                until true
                return x
            end
        ]]))

        it("can be used", function()
            run_test([[
                assert(-1 == test.sign(-10))
                assert( 0 == test.sign(0))
                assert( 1 == test.sign(10))
            ]])
        end)

        it("infinite loops don't fall through", function()
            run_test([[
                assert(42 == test.non_breaking_loop())
            ]])
        end)

        it("can initialize inside loops", function()
            run_test([[
                assert(17 == test.initialize_inside_loop())
            ]])
        end)

    end)
end)
