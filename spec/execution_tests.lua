-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = require "pallene.util"

--
-- These are the test cases that involve compiling and running a Pallene program.
-- We use these tests for the C backend (coder_spec) and the Lua backend (translator_spec).
--

local execution_tests = {}

function execution_tests.run(compile_file, backend, _ENV, only_compile)

    local it = _ENV.it
    if only_compile then
        it = function() end
    end

    local modname     = "__test_"..backend.."__"
    local file_pln    = modname..".pln"
    local file_so     = modname..".so"
    local file_lua    = modname..".lua"
    local file_script = modname.."script.lua"
    local file_output = modname.."output.txt"

    local function compile(body)
        local code = util.render([[
            local m: module = {}
            $body
            return m
        ]], {
            body = body,
        })

        if only_compile then
            _ENV.it("compiles without error", function()
                compile_file(file_pln, code)
            end)
        else
            setup(function()
                compile_file(file_pln, code)
            end)
        end
    end

    teardown(function()
        os.remove(file_pln)
        os.remove(file_so)
        os.remove(file_lua)
        os.remove(file_script)
        os.remove(file_output)
    end)

    local assert_test_output = function (expected)
        local output = assert(util.get_file_contents(file_output))
        assert.are.same(expected, output)
    end

    local run_test = function (test_script)
        util.set_file_contents(file_script, (util.render([[
            local test = require ${modname}

            local function assert_pallene_error(message, target, ...)
                if $backend == "c" then
                    local ok, err = pcall(target, ...)
                    assert(not ok)
                    assert(string.find(err, message, nil, true))
                end
            end

            local function assert_is_pallene_record(x)
                if $backend == "c" then
                    assert("userdata" == type(x))
                else
                    assert("table" == type(x))
                end
            end

            ${TEST_SCRIPT}
        ]], {
            modname = string.format("%q", modname),
            backend = string.format("%q", backend),
            TEST_SCRIPT = test_script,
        })))

        assert(util.execute(
            string.format("lua %s > %s",
                util.shell_quote(file_script),
                util.shell_quote(file_output))))
    end

    describe("Exported functions /", function()
        compile([[
            function m.f(): integer return 10 end
            local function g(): integer return 11 end
            local h
            function h(): integer return 12 end
        ]])

        it("exports public functions", function()
            run_test([[ assert(type(test.f) == "function") ]])
        end)

        it("does not export local functions (no forward decl)", function()
            run_test([[ assert(type(test.g) == "nil") ]])
        end)

        it("does not export local functions (with forward decl)", function()
            run_test([[ assert(type(test.h) == "nil") ]])
        end)
    end)

    describe("Literals /", function()
        compile([[
            function m.f_nil(): nil          return nil  end
            function m.f_true(): boolean     return true end
            function m.f_false(): boolean    return false end
            function m.f_integer(): integer  return 17 end
            function m.f_float(): float      return 3.14 end
            function m.f_string(): string    return "Hello World" end
            function m.pi(): float           return 3.141592653589793 end
            function m.e(): float            return 2.718281828459045 end
            function m.one_half(): float     return 1.0 / 2.0 end
        ]])

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

        it("floating point literals are the right type in C", function()
            -- There was a bug where (1.0/2.0) became (1/2) in the generated C
            run_test([[
                assert(0.5 == test.one_half())
            ]])
        end)
    end)

    describe("Variables /", function()
        compile([[
            function m.fst(x:integer, y:integer): integer return x end
            function m.snd(x:integer, y:integer): integer return y end

            local n = 0
            function m.next_n(): integer
                n = n + 1
                return n
            end
        ]])

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
        compile([[
            function m.f0(): integer
                return 17
            end
            function m.g0(): integer
                return m.f0()
            end
            -----------
            function m.f1(x:integer): integer
                return x
            end
            function m.g1(x:integer): integer
                return m.f1(x)
            end
            -----------
            function m.f2(x:integer, y:integer): integer
                return x+y
            end
            function m.g2(x:integer, y:integer): integer
                return m.f2(x, y)
            end
            -----------
            function m.gcd(a:integer, b:integer): integer
                if b == 0 then
                   return a
                else
                   return m.gcd(b, a % b)
                end
            end
            -----------
            function m.even(x: integer): boolean
                if x == 0 then
                    return true
                else
                    return m.odd(x-1)
                end
            end
            function m.odd(x: integer): boolean
                if x == 0 then
                    return false
                else
                    return m.even(x-1)
                end
            end
            -----------
            local l_even, l_odd
            function l_even(x: integer): boolean
                if x == 0 then
                    return true
                else
                    return l_odd(x-1)
                end
            end
            function l_odd(x: integer): boolean
                if x == 0 then
                    return false
                else
                    return l_even(x-1)
                end
            end

            function m.local_even(n: integer): boolean
                return l_even(n)
            end
            function m.local_odd(n: integer): boolean
                return l_odd(n)
            end
            -----------
            function m.skip_a() end
            function m.skip_b() m.skip_a(); m.skip_a() end
            -----------
            function m.ignore_return(): integer
                m.gcd(1,2)
                return 17
            end
            function m.ignore_return_builtin(): integer
                math.sqrt(1.0)
                return 18
            end
        ]])

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

        it("mutually recursive calls (exported)", function()
            run_test([[
                for i = 0, 5 do
                    assert( (i%2 == 0) == test.even(i) )
                    assert( (i%2 == 1) == test.odd(i) )
                end
            ]])
        end)

        it("mutually recursive calls (local)", function()
            run_test([[
                for i = 0, 5 do
                    assert( (i%2 == 0) == test.local_even(i) )
                    assert( (i%2 == 1) == test.local_odd(i) )
                end
            ]])
        end)

        it("void functions", function()
            run_test([[ assert(0 == select("#", test.skip_b())) ]])
        end)

        it("unused return value", function()
            run_test([[ assert(17 == test.ignore_return()) ]])
        end)

        it("unused return value (builtin function)", function()
            run_test([[ assert(18 == test.ignore_return_builtin()) ]])
        end)

        -- Errors

        it("missing arguments", function()
            run_test([[
                assert_pallene_error("wrong number of arguments to function 'g1', expected 1 but received 0",
                    test.g1)
            ]])
        end)

        it("too many arguments", function()
            run_test([[
                assert_pallene_error("wrong number of arguments to function 'g1', expected 1 but received 2",
                    test.g1, 10, 20)
            ]])
        end)

        it("type of argument", function()
            -- Also sees if error messages say "float" and "integer"
            -- instead of "number"
            run_test([[
                assert_pallene_error("wrong type for argument 'x', expected integer but found float",
                    test.g1, 3.14)
            ]])
        end)
    end)


    describe("First class functions /", function()
        compile([[
            function m.inc(x:integer): integer   return x + 1   end
            function m.dec(x:integer): integer   return x - 1   end

            function m.get_inc(): integer->integer
                return m.inc
            end

            --------

            function m.call(
                f : integer -> integer,
                x : integer
            ) :  integer
                return f(x)
            end

            --------

            local f: integer->integer = m.inc

            function m.setf(g:integer->integer): ()
                f = g
            end

            function m.getf(): integer->integer
                return f
            end

            function m.callf(x:integer): integer
                return f(x)
            end
        ]])

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

        it("Type-checks Lua functions", function()
            run_test([[
                local f = function(x) return "hello" end
                assert_pallene_error("wrong type for return value #1, expected integer but found string",
                    test.call, f, 0)

            ]])
        end)
    end)

    describe("Unary Operators /", function()

        local tests = {
            { "neg_i", "-",   "integer", "integer" },
            { "bnot",  "~",   "integer", "integer" },
            { "not_b", "not", "boolean", "boolean" },
            { "not_a", "not", "any",     "any"   },
        }

        local pallene_code = {}
        local test_scripts = {}

        for i, test in ipairs(tests) do
            local name, op, typ, rtyp = test[1], test[2], test[3], test[4]

            pallene_code[i] = util.render([[
                function m.$name (x: $typ): $rtyp
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

        compile(table.concat(pallene_code, "\n"))

        for _, test in ipairs(tests) do
            local name = test[1]
            it(name, function() run_test(test_scripts[name]) end)
        end
    end)

    describe("Binary Operators /", function()

        local tests = {

            -- Non-comparison operators, same order as checker.lua

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
            { "mod_if",    "%",   "integer", "float",   "float" },
            { "mod_fi",    "%",   "float",   "integer", "float" },
            { "mod_ff",    "%",   "float",   "float",   "float" },

            { "intdiv_ii", "//",  "integer", "integer", "integer" },
            { "intdiv_if", "//",  "integer", "float",   "float" },
            { "intdiv_fi", "//",  "float",   "integer", "float" },
            { "intdiv_ff", "//",  "float",   "float",   "float" },


            { "fltdiv_ii", "/",   "integer", "integer", "float" },
            { "fltdiv_ff", "/",   "float",   "float",   "float" },

            { "pow_ii",    "^",   "integer", "integer", "float" },
            { "pow_ff",    "^",   "float",   "float",   "float" },

            { "and_bb",    "and", "boolean", "boolean", "boolean" },
            { "or_bb",     "or",  "boolean", "boolean", "boolean" },

            { "and_aa",    "and", "any", "any", "any" },
            { "or_aa",     "or",  "any", "any", "any" },

            { "bor",       "|",   "integer", "integer", "integer" },
            { "band",      "&",   "integer", "integer", "integer" },
            { "bxor",      "~",   "integer", "integer", "integer" },
            { "lshift",    "<<",  "integer", "integer", "integer" },
            { "rshift",    ">>",  "integer", "integer", "integer" },

            { "concat_ss", "..",  "string",  "string",  "string" },

            -- Comparison operators, same order as types.lua
            -- Nil and Record are tested separately.

            { "eq_any", "==",  "any", "any", "boolean" },
            { "ne_any", "~=",  "any", "any", "boolean" },

            { "eq_boolean", "==",  "boolean", "boolean", "boolean" },
            { "ne_boolean", "~=",  "boolean", "boolean", "boolean" },

            { "eq_integer", "==",  "integer", "integer", "boolean" },
            { "ne_integer", "~=",  "integer", "integer", "boolean" },
            { "lt_integer", "<",   "integer", "integer", "boolean" },
            { "gt_integer", ">",   "integer", "integer", "boolean" },
            { "le_integer", "<=",  "integer", "integer", "boolean" },
            { "ge_integer", ">=",  "integer", "integer", "boolean" },

            { "eq_float", "==",  "float", "float", "boolean" },
            { "ne_float", "~=",  "float", "float", "boolean" },
            { "lt_float", "<",   "float", "float", "boolean" },
            { "gt_float", ">",   "float", "float", "boolean" },
            { "le_float", "<=",  "float", "float", "boolean" },
            { "ge_float", ">=",  "float", "float", "boolean" },

            { "eq_string", "==",  "string", "string", "boolean" },
            { "ne_string", "~=",  "string", "string", "boolean" },
            { "lt_string", "<",   "string", "string", "boolean" },
            { "gt_string", ">",   "string", "string", "boolean" },
            { "le_string", "<=",  "string", "string", "boolean" },
            { "ge_string", ">=",  "string", "string", "boolean" },

            { "eq_function", "==", "(integer, integer) -> integer",
                                   "(integer, integer) -> integer",
                                   "boolean" },
            { "ne_function", "~=", "(integer, integer) -> integer",
                                   "(integer, integer) -> integer",
                                   "boolean" },

            { "eq_array", "==", "{integer}", "{integer}", "boolean" },
            { "ne_array", "~=", "{integer}", "{integer}", "boolean" },

            { "eq_table", "==", "{x: integer, y: integer}",
                                "{x: integer, y: integer}", "boolean" },
            { "ne_table", "~=", "{x: integer, y: integer}",
                                "{x: integer, y: integer}", "boolean" },
        }

        local pallene_code = {}
        local test_scripts = {}

        for i, test in ipairs(tests) do
            local name, op, typ1, typ2, rtyp =
                test[1], test[2], test[3], test[4], test[5]

            pallene_code[i] = util.render([[
                function m.$name (x: $typ1, y:$typ2): $rtyp
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

        compile(table.concat(pallene_code, "\n"))

        for _, test in ipairs(tests) do
             local name = test[1]
             it(name, function() run_test(test_scripts[name]) end)
        end
    end)

    describe("Nil equality", function()
        compile([[
            function m.eq_nil(x: nil, y: nil): boolean
                return x == y
            end

            function m.ne_nil(x: nil, y: nil): boolean
                return x ~= y
            end

            function m.eq_any(x: any, y: any): boolean
                return x == y
            end
        ]])

        it("==", function()
            run_test([[
                assert(true == test.eq_nil(nil, nil))
                assert(true == test.eq_nil(nil, ({})[1]))
            ]])
        end)

        it("~=", function()
            run_test([[
                assert(true == test.eq_nil(nil, nil))
                assert(true == test.eq_nil(nil, ({})[1]))
            ]])
        end)

        it("is not equal to false", function()
            run_test([[
                assert(false == test.eq_any(nil, false))
            ]])
        end)
    end)

    describe("Record equality", function()
        compile([[
            record Point
                x: float
                y: float
            end

            function m.points(): {Point}
                return {
                    { x = 1.0, y = 2.0 },
                    { x = 1.0, y = 2.0 },
                    { x = 3.0, y = 4.0 },
                }
            end

            function m.eq_point(p: Point, q: Point): boolean
                return p == q
            end

            function m.ne_point(p: Point, q: Point): boolean
                return p ~= q
            end
        ]])

        it("==", function()
            run_test([[
                local p = test.points()
                for i = 1, #p do
                    for j = 1, #p do
                        local ok = (i == j)
                        assert(ok == test.eq_point(p[i], p[j]))
                    end
                end
            ]])
        end)

        it("~=", function()
            run_test([[
                local p = test.points()
                for i = 1, #p do
                    for j = 1, #p do
                        local ok = (i ~= j)
                        assert(ok == test.ne_point(p[i], p[j]))
                    end
                end
            ]])
        end)
    end)

    describe("Coercions with dynamic type /", function()

        local tests = {
            { "boolean"  , "boolean",         "true"},
            { "integer"  , "integer",         "17"},
            { "float"    , "float",           "3.14"},
            { "string"   , "string",          "'hello'"},
            { "function" , "integer->string", "tostring"},
            { "array"    , "{integer}",       "{10,20}"},
            { "table"    , "{x: integer}",    "{x = 1}"},
            { "record"   , "Empty",           "test.new_empty()"},
            { "any"      , "any",             "17"},
        }

        local record_decls = [[
            record Empty
            end
            function m.new_empty(): Empty
                return {}
            end
        ]]

        local pallene_code = {}
        local test_to      = {}
        local test_from    = {}

        for i, test in pairs(tests) do
            local name, typ, value = test[1], test[2], test[3]

            pallene_code[i] = util.render([[
                function m.from_${name}(x: ${typ}): any
                    return (x as any)
                end

                function m.to_${name}(x: any): ${typ}
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

        compile(
            record_decls .. "\n" ..
            table.concat(pallene_code, "\n")
        )

        for _, test in ipairs(tests) do
            local name = test[1]
            it(name .. "->any", function() run_test(test_to[name]) end)
        end

        for _, test in ipairs(tests) do
            local name = test[1]
            it("any->" .. name, function() run_test(test_from[name]) end)
        end

        it("detects downcast error", function()
            run_test([[
                assert_pallene_error("wrong type for downcasted value", test.to_integer, "hello")
            ]])
        end)
    end)

    describe("Statements /", function()
        compile([[
            function m.stat_blocks(): integer
                local a = 1
                local b = 2
                do
                    local a = 3
                    b = a
                    a = b + 1
                end
                return a + b
            end

            function m.sign(x: integer) : integer
                if x < 0 then
                    return -1
                elseif x == 0 then
                    return 0
                else
                    return 1
                end
            end

            function m.abs(x: integer) : integer
                if x >= 0 then
                    return x
                end
                return -x
            end

            function m.factorial_while(n: integer): integer
                local r = 1
                while n > 0 do
                    r = r * n
                    n = n - 1
                end
                return r
            end

            function m.factorial_int_for_inc(n: integer): integer
                local res = 1
                for i = 1, n do
                    res = res * i
                end
                return res
            end

            function m.factorial_int_for_dec(n: integer): integer
                local res = 1
                for i = n, 1, -1 do
                    res = res * i
                end
                return res
            end

            function m.factorial_float_for_inc(n: float): float
                local res = 1.0
                for i = 1.0, n do
                    res = res * i
                end
                return res
            end

            function m.factorial_float_for_dec(n: float): float
                local res = 1.0
                for i = n, 1.0, -1.0 do
                    res = res * i
                end
                return res
            end

            function m.repeat_until(): integer
                local x = 0
                repeat
                    x = x + 1
                    local limit = x * 10
                until limit >= 100
                return x
            end

            function m.break_while() : integer
                while true do break end
                return 17
            end

            function m.break_repeat() : integer
                repeat break until false
                return 17
            end

            function m.break_for(): integer
                local x = 0
                for i = 1, 10 do
                    x = x + i
                    break
                end
                return x
            end

            function m.nested_break(x:boolean): integer
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
        ]])

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
        compile([[
            function m.newarr(): {integer}
                return {10,20,30}
            end

            function m.len(xs:{integer}): integer
                return #xs
            end

            function m.geti(arr: {integer}, i: integer): integer
                return arr[i]
            end

            function m.seti(arr: {integer}, i: integer, v: integer)
                arr[i] = v
            end

            function m.insert(xs: {any}, v:any): ()
                xs[#xs + 1] = v
            end

            function m.remove(xs: {any}): ()
                xs[#xs] = nil
            end

            function m.getany(xs: {any}, i:integer): any
                return xs[i]
            end

            function m.getnil(xs: {nil}, i: integer): nil
                return xs[i]
            end
        ]])

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
                assert_pallene_error("wrong type for array element", test.geti, arr, 3)
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
                assert_pallene_error("invalid index", test.geti, arr, 0)
                assert_pallene_error("wrong type for array element", test.geti, arr, 4)
                table.remove(arr)
                assert_pallene_error("wrong type for array element", test.geti, arr, 3)
            ]])
        end)

        it("{nil}: in-bounds get nil", function()
            run_test([[ assert(nil == test.getnil({10, nil, 30}, 2)) ]])
        end)

        it("{nil}: out-of-bounds get nil", function()
            run_test([[ assert(nil == test.getnil({10, nil, 30}, 4)) ]])
        end)

        it("{any}: get non-nil", function()
            run_test([[ assert(10  == test.getany({10, nil, 30}, 1)) ]])
        end)

        it("{any}: in-bounds get nil", function()
            run_test([[ assert(nil == test.getany({10, nil, 30}, 2)) ]])
        end)

        it("{any}: out-of-bounds get nil", function()
            run_test([[ assert(nil == test.getany({10, nil, 30}, 4)) ]])
        end)

        it("length operator rejects arrays with a metatable", function()
            run_test([[
                local arr = {}
                setmetatable(arr, { __len = function(self) return 42 end })
                assert_pallene_error("must not have a metatable", test.len, arr)
            ]])
        end)

        it("indexing operator rejects arrays with a metatable", function()
            run_test([[
                local arr = {}
                setmetatable(arr, { __index = function(self, k) return 42 end })
                assert_pallene_error("must not have a metatable", test.getany, arr, 1)
            ]])
        end)
    end)

    describe("Tables /", function()
        local maxlenfield = string.rep('a', 40)

        compile([[
            typealias point = {x: integer, y: integer}

            function m.newpoint(): point
                return {x = 10, y = 20}
            end

            function m.getx(p: point): integer
                return p.x
            end

            function m.gety(p: point): integer
                return p.y
            end

            function m.setx(p: point, v: integer)
                p.x = v
            end

            function m.sety(p: point, v: integer)
                p.y = v
            end

            function m.getany(t: {x: any}): any
                return t.x
            end

            function m.setany(t: {x: any}, v: any)
                t.x = v
            end

            function m.getnil(t: {x: nil}): nil
                return t.x
            end

            function m.setnil(t: {x: nil})
                t.x = nil
            end

            function m.getmax(t: {]].. maxlenfield ..[[: integer}): integer
                return t.]].. maxlenfield ..[[
            end
        ]])

        it("has literals", function()
            run_test([[
                local t = test.newpoint()
                assert(type(t) == "table")
                assert(10 == t.x)
                assert(20 == t.y)
            ]])
        end)

        it("gets", function()
            run_test([[
                local p = {x = 10, y = 20}
                assert(10 == test.getx(p))
                assert(20 == test.gety(p))

                p.x = "hello"
                assert("hello" == test.getany(p))

                p.x = nil
                assert(nil == test.getany(p))
                assert(nil == test.getnil(p))
            ]])
        end)

        it("sets", function()
            run_test([[
                local p = {}
                test.setx(p, 30)
                test.sety(p, 40)
                assert(30 == p.x)
                assert(40 == p.y)

                test.setnil(p)
                assert(nil == p.x)

                test.setany(p, "hello")
                assert("hello", p.x)
            ]])
        end)

        it("checks type tags in get", function()
            run_test([[
                local p = {x = 10, y = "hello"}
                assert_pallene_error("wrong type for table field", test.gety, p)
            ]])
        end)

        it("works with fields with the max length", function()
            run_test([[
                local t = {]].. maxlenfield ..[[ = 10}
                assert(10 == test.getmax(t))
            ]])
        end)

        it("table field access rejects tables with a metatable", function()
            run_test([[
                local tab = {}
                setmetatable(tab, { __index = function(self, k) return 42 end })
                assert_pallene_error("must not have a metatable", test.getany, tab)
            ]])
        end)

        it("table field access rejects tables with a metatable", function()
            run_test([[
                local tab = {}
                setmetatable(tab, { __index = function(self, k) return 42 end })
                assert_pallene_error("must not have a metatable", test.getnil, tab)
            ]])
        end)
    end)

    describe("Strings", function()
        compile([[
            function m.len(s:string): integer
                return #s
            end
        ]])

        it("length operator (#)", function()
            run_test([[ assert( 0 == test.len("")) ]])
            run_test([[ assert( 1 == test.len("H")) ]])
            run_test([[ assert(11 == test.len("Hello World")) ]])
        end)
    end)

    describe("Typealias", function()
        compile([[
            typealias Float = float
            typealias FLOAT = float

            function m.Float2float(x: Float): float return x end
            function m.float2Float(x: float): Float return x end
            function m.Float2FLOAT(x: Float): FLOAT return x end

            record point
                x: Float
            end

            typealias Point = point
            typealias Points = {Point}

            function m.newPoint(x: Float): Point
                return {x = x}
            end

            function m.get(p: Point): FLOAT
                return p.x
            end

            function m.addPoint(ps: Points, p: Point)
                ps[#ps + 1] = p
            end
        ]])

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
        compile([[
            record Foo
                x: integer
                y: {integer}
            end

            function m.make_foo(x: integer, y: {integer}): Foo
                return { x = x, y = y }
            end

            function m.get_x(foo: Foo): integer
                return foo.x
            end

            function m.set_x(foo: Foo, x: integer)
                foo.x = x
            end

            function m.get_y(foo: Foo): {integer}
                return foo.y
            end

            function m.set_y(foo: Foo, y: {integer})
                foo.y = y
            end

            record Prim
                x: integer
            end

            function m.make_prim(x: integer): Prim
                return { x = x }
            end

            record Gc
                x: {integer}
            end

            function m.make_gc(x: {integer}): Gc
                return { x = x }
            end

            record Empty
            end

            function m.make_empty(): Empty
                return {}
            end
        ]])

        it("create records", function()
            run_test([[
                local x = test.make_foo(123, {})
                assert_is_pallene_record(x)
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
                assert_is_pallene_record(x)
            ]])
        end)

        it("create records with only gc fields", function()
            run_test([[
                local x = test.make_gc({})
                assert_is_pallene_record(x)
            ]])
        end)

        it("create empty records", function()
            run_test([[
                local x = test.make_empty()
                assert_is_pallene_record(x)
            ]])
        end)

        it("check record tags", function()
            -- TODO: change this message to mention the relevant record types
            -- instead of only saying "userdata"
            run_test([[
                local prim = test.make_prim(123)
                assert_pallene_error("expected userdata but found userdata", test.get_x, prim)
            ]])
        end)

        -- The follow test case is special. Therefore, we manually check the backend we are testing
        -- before executing it.
        if backend == "c" then
            it("protect record metatables", function()
                run_test([[
                    local x = test.make_prim(123)
                    assert(getmetatable(x) == false)
                ]])
            end)
        end
    end)

    describe("I/O", function()
        compile([[
            function m.write(s:string)
                io.write(s)
            end
        ]])

        it("io.write works", function()
            run_test([[
                test.write("Hello:)World")
            ]])
            assert_test_output("Hello:)World")
        end)
    end)

    describe("math.huge builtin", function()
        compile([[
            function m.get_huge(): float
                return math.huge
            end
        ]])

        it("Pallene huge equals Lua huge", function()
            run_test([[
                assert(math.huge == test.get_huge())
            ]])
        end)
    end)

    describe("math.mininteger builtin", function()
        compile([[
            function m.get_mininteger(): integer
                return math.mininteger
            end
        ]])

        it("Pallene mininteger equals Lua mininteger", function()
            run_test([[
                assert(math.mininteger == test.get_mininteger())
            ]])
        end)
    end)

    describe("math.maxinteger builtin", function()
        compile([[
            function m.get_maxinteger(): integer
                return math.maxinteger
            end
        ]])

        it("Pallene maxinteger equals Lua maxinteger", function()
            run_test([[
                assert(math.maxinteger == test.get_maxinteger())
            ]])
        end)
    end)

    describe("math.pi builtin", function()
        compile([[
            function m.get_pi(): float
                return math.pi
            end
        ]])

        it("Pallene pi equals Lua pi", function()
            run_test([[
                assert(math.pi == test.get_pi())
            ]])
        end)
    end)

    -- Note: Implementation currenly only supports float and uses fabs().
    -- Test avoids differences that may be caused by needing integers.
    describe("math.abs builtin", function()
        compile([[
            function m.absolute_value(x: float): float
                return math.abs(x)
            end
        ]])

        it("works on positive numbers", function()
            run_test([[
                assert(1.0 == test.absolute_value(1.0))
                assert(7.0 == test.absolute_value(7.0))
            ]])
        end)

        it("works on negative numbers", function()
            run_test([[
                assert(1.0 == test.absolute_value(-1.0))
                assert(11.0 == test.absolute_value(-11.0))
            ]])
        end)

        it("returns NaN on NaN", function()
            run_test([[
                local x = test.absolute_value(0.0 / 0.0)
                assert(x ~= x)
            ]])
        end)
    end)

    describe("math.ceil builtin", function()
        compile([[
            function m.ceil_value(x: float): integer
                return math.ceil(x)
            end
        ]])

        it("works on positive numbers", function()
            run_test([[
                assert(1 == test.ceil_value(1.0))
                assert(8 == test.ceil_value(7.7))
            ]])
        end)

        it("works on negative numbers", function()
            run_test([[
                assert(-1 == test.ceil_value(-1.0))
                assert(-11 == test.ceil_value(-11.7))
            ]])
        end)
    end)

    describe("math.floor builtin", function()
        compile([[
            function m.floor_value(x: float): integer
                return math.floor(x)
            end
        ]])

        it("works on positive numbers", function()
            run_test([[
                assert(1 == test.floor_value(1.0))
                assert(7 == test.floor_value(7.7))
            ]])
        end)

        it("works on negative numbers", function()
            run_test([[
                assert(-1 == test.floor_value(-1.0))
                assert(-12 == test.floor_value(-11.7))
            ]])
        end)
    end)

    describe("math.fmod builtin", function()
        compile([[
            function m.fmod_value(x: float, y: float): float
                return math.fmod(x, y)
            end
        ]])

        it("works on positive numbers", function()
            run_test([[
                assert(0.0 == test.fmod_value(8.0, 2.0))
                assert(2.0 == test.fmod_value(8.0, 3.0))
                assert(1.4 == test.fmod_value(1.4, 3.0))
                assert(0.5 == test.fmod_value(8.0, 2.5))
            ]])
        end)

        it("works on negative numbers", function()
            run_test([[
                assert(2.0 == test.fmod_value(8.0, -3.0))
                assert(-2.0 == test.fmod_value(-8.0, 3.0))
                assert(-1.4 == test.fmod_value(-1.4, 3.0))
                assert(-0.5 == test.fmod_value(-8.0, 2.5))
            ]])
        end)

        it("returns NaN on NaN", function()
            run_test([[
                local x = test.fmod_value(0.0 / 0.0, 0.0 / 0.0)
                assert(x ~= x)
            ]])
        end)
    end)

    describe("math.exp builtin", function()
        compile([[
            function m.exponential_value(x: float): float
                return math.exp(x)
            end
        ]])

        it("works on positive numbers", function()
            run_test([[
                assert(1.0 == test.exponential_value(0.0))
                assert(2.718 == tonumber(string.format("%.3f",
                    test.exponential_value(1.0))))
            ]])
        end)

        it("works on negative numbers", function()
            run_test([[
                assert(0.368 == tonumber(string.format("%.3f", test.exponential_value(-1.0))))
            ]])
        end)

        it("returns NaN on NaN", function()
            run_test([[
                local x = test.exponential_value(0.0 / 0.0)
                assert(x ~= x)
            ]])
        end)
    end)

    describe("math.ln builtin", function()
        compile([[
            function m.natural_log(x: float): float
                return math.ln(x)
            end
        ]])

        it("works on positive numbers", function()
            run_test([[
                assert(0.0 == test.natural_log(1.0))
                assert(0.693 == tonumber(string.format("%.3f", test.natural_log(2.0))))
                assert(2.303 == tonumber(string.format("%.3f", test.natural_log(10.0))))
            ]])
        end)

        it("returns NaN on negative numbers", function()
            run_test([[
                local x = test.natural_log(-1.0)
                assert(x ~= x)
            ]])
        end)

        it("returns NaN on NaN", function()
            run_test([[
                local x = test.natural_log(0.0 / 0.0)
                assert(x ~= x)
            ]])
        end)
    end)

    describe("math.log builtin", function()
        compile([[
            function m.math_log(x: float, base: float): float
                return math.log(x, base)
            end
        ]])

        it("works on positive numbers", function()
            run_test([[
                assert(0.0 == test.math_log(1.0, 2.0))
                assert(0.0 == test.math_log(1.0, 10.0))
                assert(0.0 == test.math_log(1.0, 16.0))
                assert(1.0 == test.math_log(2.0, 2.0))
                assert(1.0 == test.math_log(10.0, 10.0))
                assert(1.0 == test.math_log(16.0, 16.0))
                assert(10.0 == test.math_log(1024.0, 2.0))
                assert(2.0 == test.math_log(100.0, 10.0))
                assert(2.5 == test.math_log(1024.0, 16.0))
            ]])
        end)

        it("returns NaN on negative numbers", function()
            run_test([[
                local x = test.math_log(-100.0, 10.0)
                assert(x ~= x)
            ]])
        end)

        it("returns NaN on NaN", function()
            run_test([[
                local x = test.math_log(0.0 / 0.0, 0.0 / 0.0)
                assert(x ~= x)
            ]])
        end)
    end)

    describe("math.modf builtin", function()
        compile([[
            function m.math_modf(x: float): (integer, float)
                return math.modf(x)
            end
        ]])

        it("works on positive numbers", function()
            run_test([[
                local integral, fractional = test.math_modf(1.0)
                assert(1 == integral)
                assert(0.0 == tonumber(string.format("%.1f", fractional)))
                local integral, fractional = test.math_modf(2.3)
                assert(2 == integral)
                assert(0.3 == tonumber(string.format("%.1f", fractional)))
            ]])
        end)

        it("works on negative numbers", function()
            run_test([[
                local integral, fractional = test.math_modf(-1.0)
                assert(-1 == integral)
                assert(0.0 == tonumber(string.format("%.1f", fractional)))
                local integral, fractional = test.math_modf(-2.3)
                assert(-2 == integral)
                assert(-0.3 == tonumber(string.format("%.1f", fractional)))
            ]])
        end)
    end)

    describe("math.pow builtin", function()
        compile([[
            function m.math_pow(x: float, y: float): float
                return math.pow(x, y)
            end
        ]])

        it("works on positive numbers", function()
            run_test([[
                assert(1.0 == test.math_pow(1.0, 2.0))
                assert(1.0 == test.math_pow(10.0, 0.0))
                assert(8.0 == test.math_pow(2.0, 3.0))
                assert(243.0 == test.math_pow(9.0, 2.5))
            ]])
        end)

        it("works on negative numbers", function()
            run_test([[
                assert(81.0 == test.math_pow(-9.0, 2.0))
                assert(0.25 == test.math_pow(2.0, -2.0))
            ]])
        end)

        it("returns NaN on NaN", function()
            run_test([[
                local x = test.math_pow(0.0 / 0.0, 0.0 / 0.0)
                assert(x ~= x)
            ]])
        end)
    end)

    describe("math.sqrt builtin", function()
        compile([[
            function m.square_root(x: float): float
                return math.sqrt(x)
            end
        ]])

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
        compile([[
            function m.chr(x: integer): string
                return string.char(x)
            end
        ]])

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
        compile([[
            function m.sub(s: string, i: integer, j: integer): string
                return string.sub(s, i, j)
            end
        ]])

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

    describe("any", function()
        compile([[
            function m.id(x:any): any
                return x
            end

            function m.call(f:any->any, x:any): any
                return f(x)
            end

            function m.read(xs:{any}, i:integer): any
                return xs[i]
            end

            function m.write(xs:{any}, i:integer, x:any): ()
                xs[i] = x
            end

            function m.if_any(x:any): boolean
                if x then
                    return true
                else
                    return false
                end
            end

            function m.while_any(x:any): integer
                local out = 0
                while x do
                    out = out + 1
                    x = false
                end
                return out
            end

            function m.repeat_any(x:any): integer
                local out = 0
                repeat
                    out = out + 1
                    if out == 2 then
                        break
                    end
                until x
                return out
            end
        ]])

        --
        -- All of these have a separate branch for the "any" and the non-"any"
        -- case. So we better stress them by testing the "any" case...
        --

        it("can receive and return anys", function()
            run_test([[ assert(17 == test.id(17)) ]])
            run_test([[ assert(true == test.id(true)) ]])
            run_test([[ assert(true == test.call(test.id, true)) ]])
        end)

        it("can read from array of any", function()
            run_test([[
                local xs = {10, "hello"}
                assert(10 == test.read(xs, 1))
                assert("hello" == test.read(xs, 2))
            ]])
        end)

        it("can write to array of any", function()
            run_test([[
                local xs = {}
                test.write(xs, 1, 10)
                test.write(xs, 2, "hello")
                assert(10 == xs[1])
                assert("hello" == xs[2])
            ]])
        end)

        it("can use any in if-statement condition", function()
            run_test([[
                assert(true == test.if_any(0))
                assert(true == test.if_any(true))
                assert(false == test.if_any(false))
                assert(false == test.if_any(nil))
            ]])
        end)

        it("can use any in while-statement condition", function()
            run_test([[
                assert(1 == test.while_any(0))
                assert(1 == test.while_any(true))
                assert(0 == test.while_any(false))
                assert(0 == test.while_any(nil))
            ]])
        end)

        it("can use any in repeat-until-statement condition", function()
            run_test([[
                assert(1 == test.repeat_any(0))
                assert(1 == test.repeat_any(true))
                assert(2 == test.repeat_any(false))
                assert(2 == test.repeat_any(nil))
            ]])
        end)
    end)

    describe("Corner cases of exporting variables", function ()
        compile([[
            local  a = 10
            m.b = 20
            local  c = 30
            m.d = 40
        ]])

        it("ensure that when globals are optimized away, the variables being exported are the right ones", function ()
            run_test([[ assert(nil == test.a) ]])
            run_test([[ assert(20 == test.b) ]])
            run_test([[ assert(nil == test.c) ]])
            run_test([[ assert(40 == test.d) ]])
        end)
    end)

    describe("Corner cases of scoping", function()
        compile([[
            record Point
                x: integer
                y: integer
            end

            local x = 10

            typealias y = integer

            ------

            local j : integer = 5319

            ------

            m.integer = 12

            ------

            function m.local_type(): integer
                local Point: Point = { x=1, y=2 }
                return Point.x
            end

            function m.local_initializer(): integer
                local x = x + 1
                return x
            end

            function m.for_type_annotation(): integer
                local res = 0
                for y:y = 1, 10 do
                    res = res + y
                end
                return res
            end

            function m.for_initializer(): integer
                local res = 0
                for x = x + 1, x + 100, x-7 do
                    res = res + 1
                end
                return res
            end

            function m.duplicate_parameter(x: integer, x:integer) : integer
                return x
            end

            function m.variable_called_module(): integer
                local module = 10
                return module + 7
            end

            typealias module = integer
            function m.type_called_module(): module
                return 18
            end
        ]])

        it("ensure that local variables are not exported", function ()
            run_test([[ assert(nil == test.j) ]])
        end)

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

        it("allows functions with repeated argument names", function()
            run_test([[ assert( 20 == test.duplicate_parameter(10, 20) )]])
        end)

        it("allows identifiers named like builtin types", function()
            run_test([[ assert( 12 == test.integer) ]])
        end)

        it("allows 'module' as a variable name", function()
            run_test([[ assert( 17 == test.variable_called_module() ) ]])
        end)

        it("allows 'module' as a type name", function()
            run_test([[ assert( 18 == test.type_called_module() ) ]])
        end)
    end)

    describe("Non-constant toplevel initializers", function()
        compile([[
            function m.f(): integer
                return 10
            end

            local x1 = m.f()
            local x2 = x1
            local x3 = -x2
            local x4: {integer} = { x1 }
            local x5: {x: integer} = { x = x1 }

            function m.get_x1(): integer
                return x1
            end

            function m.get_x2(): integer
                return x2
            end

            function m.get_x3(): integer
                return x3
            end

            function m.get_x4(): {integer}
                return x4
            end

            function m.get_x5(): {x: integer}
                return x5
            end
        ]])

        it("", function()
            run_test([[
                assert(  10 == test.get_x1() )
                assert(  10 == test.get_x2() )
                assert( -10 == test.get_x3() )
                local x4 = test.get_x4()
                assert( 1 == #x4 )
                assert( 10 == x4[1] )
                local x5 = test.get_x5()
                assert(10 == x5.x)
            ]])
        end)
    end)

    describe("Nested for loops", function()
        compile([[
            function m.mul(n: integer, m:integer) : integer
                local ret = 0
                for i = 1, n do
                    for j = 1, m do
                        ret = ret + 1
                    end
                end
                return ret
            end
        ]])

        it("", function()
            run_test([[
                assert( 0 == test.mul(0, 2))
                assert( 0 == test.mul(2, 0))
                assert(15 == test.mul(3, 5))
            ]])
        end)
    end)

    describe("For-in loops", function()
        compile([[
            local function iter(arr: {any}, prev: integer): (any, any)
                local i = prev + 1
                local x = arr[i]
                if x == (nil as any) then
                    return nil, nil
                end

                return i, x
            end


            typealias iterfn = (any, any) -> (any, any)
            local function my_ipairs(xs: {any}): (iterfn, any, any)
                return iter, xs, 0
            end

            -----------------------

            function m.double_list(xs: {integer}): {integer}
                local out: {integer} = {}
                for i, x in my_ipairs(xs) do
                    out[i] = x as integer * 2
                end

                return out
            end

            -----------------------

            function m.flatten_list(grid: {{integer}}): {integer}
                local out: {integer} = {}
                for _, xs in my_ipairs(grid) do
                    for _, x in my_ipairs(xs) do
                        out[#out + 1] = x
                    end
                end
                return out
            end

            -----------------------

            function m.square_list(xs: {integer}): {integer}
                local out: {integer} = {}
                for i, v in iter as iterfn, xs as any, 0 as any do
                    out[i] = (v as integer) * (v as integer)
                end
                return out
            end

            -----------------------

            function m.sum_list(xs: {integer}): integer
                local sum = 0
                for _: integer, x: integer in my_ipairs(xs) do
                    sum = sum + x
                end
                return sum
            end

            -----------------------

            function m.double_list_ipairs(xs: {integer}): {integer}
                local out: {integer} = {}
                for i, x in ipairs(xs) do
                    out[i] = x as integer * 2
                end
                return out
            end

            -----------------------

            function m.sum_list_ipairs(xs: {integer}): integer
                local sum = 0
                for _: integer, x: integer in ipairs(xs) do
                    sum = sum + x
                end
                return sum
            end
        ]])

        it("general for-in loops", function()
            run_test([[
                local xs = test.double_list({1, 2})
                assert(xs[1] == 2 and xs[2] == 4)
            ]])
        end)

        it("nested for-in loops", function()
            run_test([[
                local xs = test.flatten_list({{1, 2}, {3, 4}})
                assert(xs[1] == 1 and xs[2] == 2 and xs[3] == 3 and xs[4] == 4)
            ]])
        end)

        it("loops with expanded RHS", function()
            run_test([[
                local xs = test.square_list({2, 3, 4})
                assert(xs[1] == 4 and xs[2] == 9 and xs[3] == 16)
            ]])
        end)

        it("loops with type annotated LHS.", function()
            run_test([[
                local sum = test.sum_list({1, 2, 3, 4})
                assert(sum == 10)
            ]])
        end)

        it("for-in loops with ipairs", function()
            run_test([[
                local xs = test.double_list_ipairs({1, 2})
                assert(xs[1] == 2 and xs[2] == 4)
            ]])
        end)

        it("for-in loops with ipairs and type annotated LHS", function()
            run_test([[
                local sum = test.sum_list_ipairs({1, 2, 3})
                assert(sum == 6)
            ]])
        end)

        it("for-in loops with holes", function()
            run_test([[
                local sum = test.sum_list_ipairs({1, 2, 3, nil, 4, 5})
                assert(sum == 6)
            ]])
        end)

    end)

    describe("Constant propagation", function()
        compile([[
            local x = 0 -- never read from
            local step = 1
            local counter = 0

            local function inc(): integer
                counter = counter + step
                return counter
            end

            function m.next(): integer
                x = inc()
                return counter
            end
        ]])

        it("preserves assignment side-effects", function()
            run_test([[
                assert(1 == test.next())
                assert(2 == test.next())
                assert(3 == test.next())
            ]])
        end)
    end)

    -- https://github.com/pallene-lang/pallene/issues/508
    describe("Issue 508:", function()
        compile([[
            local N = 42

            function m.f()
            end

            function m.g(): integer
                local x = N
                m.f()
                return x
            end
        ]])
        it("Constant propagation correctly renumbers the upvalues", function()
            run_test([[
                assert(42 == test.g())
            ]])
        end)
    end)

    describe("Uninitialized variables", function()
        compile([[
            function m.sign(x: integer): integer
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

            function m.non_breaking_loop(): integer
                local i = 1
                while true do
                    if i == 42 then return i end
                    i = i + 1
                end
            end

            function m.initialize_inside_loop(): integer
                local x: integer
                repeat
                    x = 17
                until true
                return x
            end
        ]])

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

    describe("For loop integer overflow", function()
        compile([[
            function m.loop(A: integer, B: integer, C: integer): {integer}
                local xs: {integer} = {}
                for i = A, B, C do
                    xs[#xs+1] = i
                end
                return xs
            end
        ]])

        it("int loop avoids overflow", function()
            run_test([[
                local high = math.maxinteger
                local xs = test.loop(high-5, high, 10)
                assert(#xs == 1)
                assert(xs[1] == high-5)
            ]])
        end)

        it("int loop avoids underderflow", function()
            run_test([[
                local low = math.mininteger
                local xs = test.loop(low+5, low, -10)
                assert(#xs == 1)
                assert(xs[1] == low+5)
            ]])
        end)

        it("very large interval (up)", function()
            run_test([[
                local low  = math.mininteger
                local high = math.maxinteger
                local xs = test.loop(low, high, high)
                assert(#xs == 3)
                assert(xs[1] == low)
                assert(xs[2] == -1)
                assert(xs[3] == high-1)
            ]])
        end)

        it("very large interval (down)", function()
            run_test([[
                local low  = math.mininteger
                local high = math.maxinteger
                local xs = test.loop(high, low, low)
                assert(#xs == 2)
                assert(xs[1] == high)
                assert(xs[2] == -1)
            ]])
        end)
    end)

    describe("Multiple assignment", function()
        compile([[
            typealias TPoint = {x:integer, y:integer}

            record RPoint
                x: integer
                y: integer
            end

            function m.new_rpoint(x:integer, y:integer): RPoint
                return {x = x, y = y}
            end

            function m.get_rpoint_fields(p:RPoint): (integer, integer)
                return p.x, p.y
            end

            local gi, ga: {integer} = 1, {}
            function m.assign_global(): (integer, {integer})
                gi, ga[gi] = gi+1, 20
                return gi, ga
            end

            function m.assign_local(): (integer, {integer})
                local li: integer = 1
                local la: {integer} = {}

                li, la[li] = li+1, 20
                return li, la
            end

            function m.assign_bracket(): (integer, integer)
                local a: {integer} = {10, 20}

                a[1], a[2] = a[2], a[1]
                return a[1], a[2]
            end

            function m.swap(): (integer, integer)
                local x, y = 10, 20
                x, y = y, x
                return x, y
            end

            function m.swap_point(): TPoint
                local p:TPoint = { x = 10, y = 20 }
                p.x, p.y = p.y, p.x
                return p
            end

            function m.assign_tables_1(a:{integer}, b:{integer}, c:integer): ({integer}, {integer})
                a, a[1] = b, c
                return a, b
            end

            function m.assign_tables_2(a:{integer}, b:{integer}, c:integer): ({integer}, {integer})
                a[1], a = c, b
                return a, b
            end

            function m.assign_dots_1(a:TPoint, b:TPoint, c:integer, d:integer): (TPoint, TPoint)
                a, a.x, a.y = b, c, d
                return a, b
            end

            function m.assign_dots_2(a:TPoint, b:TPoint, c:integer, d:integer): (TPoint, TPoint)
                a.x, a.y, a = c, d, b
                return a, b
            end

            function m.assign_recs_1(a:RPoint, b:RPoint, c:integer, d:integer): (RPoint, RPoint)
                a, a.x, a.y = b, c, d
                return a, b
            end

            function m.assign_recs_2(a:RPoint, b:RPoint, c:integer, d:integer): (RPoint, RPoint)
                a.x, a.y, a = c, d, b
                return a, b
            end

            function m.assign_same_var(): integer
                local a:integer
                a, a, a = 10, 20, 30
                return a
            end


            local gn = 0
            local function inc(): integer
                gn = gn + 1
                return gn
            end

            local x = inc(), inc()

            function m.extra_values_in_toplevel_decl(): (integer, integer)
                return x, gn
            end

            function m.extra_values_in_local_decl(): (integer, integer)
                gn = 10
                local y = inc(), inc()
                return y, gn
            end

            function m.extra_values_in_assign_stat(): (integer, integer)
                local y: integer
                gn = 20
                y = inc(), inc()
                return y, gn
            end
        ]])

        it("preserves evaluation order with local variables", function()
            run_test([[
                local i, ai = test.assign_local()
                assert(2   == i)
                assert(20  == ai[1])
                assert(nil == ai[2])
            ]])
        end)

        it("preserves evaluation order with global variables", function()
            run_test([[
                local i, ai = test.assign_global()
                assert(2   == i)
                assert(20  == ai[1])
                assert(nil == ai[2])
            ]])
        end)

        it("preserves evaluation order with bracket variables", function()
            run_test([[
                local i, j = test.assign_bracket()
                assert(20 == i)
                assert(10 == j)
            ]])
        end)

        it("preserves evaluation order with dot variables", function()
            run_test([[
                local p = test.swap_point()
                assert(20 == p.x)
                assert(10 == p.y)
            ]])
        end)

        it("swap variables correctly", function()
            run_test([[
                local x, y = test.swap()
                assert(20 == x)
                assert(10 == y)
            ]])
        end)

        it("use temporary variables correctly on arrays assignments 1", function()
            run_test([[
                local a, b = {10}, {20}
                local t = table.pack(test.assign_tables_1(a, b, 30))
                assert(2  == t.n)
                assert(b  == t[1])
                assert(b  == t[2])
                assert(30 == a[1])
                assert(20 == b[1])
            ]])
        end)

        it("use temporary variables correctly on arrays assignments 2", function()
            run_test([[
                local a, b = {10}, {20}
                local t = table.pack(test.assign_tables_2(a, b, 30))
                assert(2  == t.n)
                assert(b  == t[1])
                assert(b  == t[2])
                assert(30 == a[1])
                assert(20 == b[1])
            ]])
        end)

        it("use temporary variables correctly on tables assignments 1", function()
            run_test([[
                local a, b = {x = 10, y = 20}, {x = 30, y = 40}
                local t = table.pack(test.assign_dots_1(a, b, 50, 60))
                assert(2  == t.n)
                assert(b  == t[1])
                assert(b  == t[2])
                assert(50 == a.x)
                assert(60 == a.y)
                assert(30 == b.x)
                assert(40 == b.y)
            ]])
        end)

        it("use temporary variables correctly on tables assignments 2", function()
            run_test([[
                local a, b = {x = 10, y = 20}, {x = 30, y = 40}
                local t = table.pack(test.assign_dots_2(a, b, 50, 60))
                assert(2  == t.n)
                assert(b  == t[1])
                assert(b  == t[2])
                assert(50 == a.x)
                assert(60 == a.y)
                assert(30 == b.x)
                assert(40 == b.y)
            ]])
        end)

        it("use temporary variables correctly on records assignments 1", function()
            run_test([[
                local a, b = test.new_rpoint(10, 20), test.new_rpoint(30, 40)
                local t = table.pack(test.assign_recs_1(a, b, 50, 60))
                local ax, ay = test.get_rpoint_fields(a)
                local bx, by = test.get_rpoint_fields(b)
                assert(2  == t.n)
                assert(b  == t[1])
                assert(b  == t[2])
                assert(50 == ax)
                assert(60 == ay)
                assert(30 == bx)
                assert(40 == by)
            ]])
        end)

        it("use temporary variables correctly on records assignments 2", function()
            run_test([[
                local a, b = test.new_rpoint(10, 20), test.new_rpoint(30, 40)
                local t = table.pack(test.assign_recs_2(a, b, 50, 60))
                local ax, ay = test.get_rpoint_fields(a)
                local bx, by = test.get_rpoint_fields(b)
                assert(2  == t.n)
                assert(b  == t[1])
                assert(b  == t[2])
                assert(50 == ax)
                assert(60 == ay)
                assert(30 == bx)
                assert(40 == by)
            ]])
        end)

        it("multiple assignment to same variable works correctly", function()
            run_test([[
                local a = test.assign_same_var()
                assert(10 == a)
            ]])
        end)

        it("assignment to toplevel decl does not discard extra arguments in RHS", function()
            run_test([[
                local x, n = test.extra_values_in_toplevel_decl()
                assert(2 == n)
                assert(1 == x)
            ]])
        end)

        it("assignment to local decl does not does not discard extra arguments in RHS", function()
            run_test([[
                local x, n = test.extra_values_in_local_decl()
                assert(12 == n)
                assert(11 == x)
            ]])
        end)

        it("assignment statement does not does not discard extra arguments in RHS", function()
            run_test([[
                local x, n = test.extra_values_in_assign_stat()
                assert(22 == n)
                assert(21 == x)
            ]])
        end)
    end)

    describe("Multiple returns", function()
        compile([[
            function m.f(): (integer, integer, integer)
                return 10, 20, 30
            end

            function m.g(x:integer, y:integer, z:integer): integer
                return x + y + z
            end

            function m.func_as_param(): integer
                local a = m.g(m.f())
                return a
            end

            function m.func_as_return(): (integer, integer, integer)
                return m.f()
            end

            function m.func_as_first_return(): (integer, integer)
                return m.f(), 42
            end

            function m.func_as_only_exp(): integer
                local a, b, c = m.f()
                return a + b + c
            end

            function m.func_inside_paren(): integer
                return (m.f())
            end

            function m.callstatic_assign_same_var_1(): integer
                local x: integer
                x, x, x = m.f()
                return x
            end

            function m.callstatic_assign_same_var_2(): integer
                local x: integer
                local y: integer
                x, y, y = m.f()
                return y
            end

            function m.calldyn_assign_same_var_1(p: ()->(integer,integer,integer)): integer
                local x: integer
                x, x, x = p()
                return x
            end

            function m.calldyn_assign_same_var_2(p: ()->(integer,integer,integer)): integer
                local x: integer
                local y: integer
                x, y, y = p()
                return y
            end
        ]])

        it("works as function arguments", function()
            run_test([[
                local a = test.func_as_param()
                assert(60 == a)
            ]])
        end)

        it("works as only return value on multiple return", function()
            run_test([[
                local t = table.pack(test.func_as_return())
                assert(3  == t.n)
                assert(10 == t[1])
                assert(20 == t[2])
                assert(30 == t[3])
            ]])
        end)

        it("works as first return value on multiple return", function()
            run_test([[
                local t = table.pack(test.func_as_first_return())
                assert(2  == t.n)
                assert(10 == t[1])
                assert(42 == t[2])
            ]])
        end)

        it("works as only expression on a declaration", function()
            run_test([[
                local a = test.func_as_only_exp()
                assert(60 == a)
            ]])
        end)

        it("works inside parenthesis", function()
            run_test([[
                local t = table.pack(test.func_inside_paren())
                assert(1  == t.n)
                assert(10 == t[1])
            ]])
        end)

        it("assigns return values from right to left (callstatic/1)", function()
            run_test([[
                local x = test.callstatic_assign_same_var_1()
                assert(x == 10)
            ]])
        end)

        it("assigns return values from right to left (callstatic/2)", function()
            run_test([[
                local y = test.callstatic_assign_same_var_2()
                assert(y == 20)
            ]])
        end)

        it("assigns return values from right to left (calldyn/1)", function()
            run_test([[
                local x = test.calldyn_assign_same_var_1(test.f)
                assert(x == 10)
            ]])
        end)

        it("assigns return values from right to left (calldyn/2)", function()
            run_test([[
                local y = test.calldyn_assign_same_var_2(test.f)
                assert(y == 20)
            ]])
        end)
    end)


    describe("Closures", function()

        compile([[
            function m.increment(x: integer): integer
                local inc: integer -> integer = function (x)
                    return x + 1
                end
                return inc(x)
            end

            function m.make_incrementer(): integer -> integer
                return function (x)
                    return x + 1
                end
            end

            function m.add(x: integer, y: integer): integer
                local addX: integer -> integer = function(z)
                    return z + x
                end
                return addX(y)
            end

            function m.make_adder(y: integer): integer -> integer
                return function(x)
                    return x + y
                end
            end

            function m.add3(x: integer, y: integer, z: integer): integer
                local add: integer -> integer = function(a)
                    local f: integer -> integer = function(b)
                        return b + z
                    end
                    return a + f(y)
                end
                return add(x)
            end

            function m.wrap(x: integer): (integer -> (), () -> integer)
                local n: integer = x
                local set: integer -> () = function (y)
                    n = y
                end

                local get: () -> integer = function()
                    return n
                end

                return set, get
            end

            function m.counter(x: integer): (() -> integer)
                return function ()
                    x = x + 1
                    return x
                end
            end

            function m.swapper(x: integer, y: integer): (() -> (integer, integer))
                return function ()
                    x, y = y, x
                    return x, y
                end
            end

            function m.make_counter(start_at_0: boolean): (() -> integer)
                local x: integer
                if start_at_0 then
                    x = 0
                else
                    x = 1
                end

                return function()
                    x = x + 1
                    return x - 1
                end
            end

            function m.count_from(n: integer): () -> (integer, any)
                return function()
                    return n + 1, m.count_from(n + 1)
                end
            end

            function m.double(x: integer): integer
                local function f(): integer
                    return 2 * x
                end
                local function g(): integer
                    return f()
                end
                return g()
            end

            function m.oddeven(n: integer): string
                local l_even, l_odd
                function l_even(x: integer): boolean
                    if x == 0 then
                        return true
                    else
                        return l_odd(x-1)
                    end
                end
                function l_odd(x: integer): boolean
                    if x == 0 then
                        return false
                    else
                        return l_even(x-1)
                    end
                end
                if l_even(n) then return "even" end
                return "odd"
            end

        ]])

        it("works correctly with non-capturing closures", function ()
            run_test([[ assert(test.increment(10) == 11) ]])
        end)

        it("can return a non-capturing closure", function()
            run_test([[
                local add1 = test.make_incrementer()
                assert(add1(21) == 22)
            ]])
        end)

        it("capturing closures work as expected", function()
            run_test([[assert(test.add(10, 20) == 30)]])
        end)

        it("Intermediate closures can capture upvalues to pass them down to nested closures", function()
            run_test([[assert(test.add3(10, 20, 30) == 60)]])
        end)

        it("can return a capturing closure", function()
            run_test([[
                local add10 = test.make_adder(10)
                assert(add10(20) == 30)
            ]])
        end)


        it("Mutating and capturing closures work as expected", function()
            run_test([[
                local set, get = test.wrap(10)
                assert(get() == 10)
                set(100)
                assert(get() == 100)
            ]])
        end)

        it("Capturing parameters and mutating them works", function()
            run_test([[
                local tick = test.counter(1)
                assert(tick() == 2)
                assert(tick() == 3)
            ]])
        end)

        it("Can capture multiple parameters", function()
            run_test([[
                local swap = test.swapper(1, 2)
                local x, y = swap()
                assert(x == 2 and y == 1)
                x, y = swap()
                assert(x == 1 and y == 2)
            ]])
        end)

        it("Can capture upvalues that aren't initialized upon declaration", function()
            run_test([[
                local count = test.make_counter(false)
                assert(count() == 1)
                assert(count() == 2)

                local count2 = test.make_counter(true)
                assert(count2() == 0)
                assert(count2() == 1)
                assert(count2() == 2)
            ]])
        end)

        it("Can capture a surrounding function", function ()
            run_test([[
                local n, next = 0, test.count_from(0)
                n, next = next()
                assert(n == 1)
                n, next = next()
                assert(n == 2)
            ]])
        end)

        it("Function statements can be captured as upvalues", function ()
            run_test("assert(test.double(5) == 10)")
        end)

        it("Mutually recursive closures work as expected", function ()
            run_test("assert(test.oddeven(50) == 'even')")
        end)

    end)

    describe("tostring builtin", function ()
        compile([[
            function m.f(x: any): string
                return tostring(x)
            end
        ]])

        it("works correctly with integer argument", function()
            run_test([[ assert(test.f(42) == "42") ]])
        end)

        it("works correctly with float argument", function()
            run_test([[ assert(test.f(3.1415) == "3.1415") ]])
        end)

        it("works correctly with boolean argument (true)", function()
            run_test([[ assert(test.f(true) == "true") ]])
        end)

        it("works correctly with boolean argument (false)", function()
            run_test([[ assert(test.f(false) == "false") ]])
        end)

        it("works correctly with string argument", function()
            run_test([[ assert(test.f("this is a string") == "this is a string") ]])
        end)

        it("error case", function()
            run_test([[
                assert_pallene_error("tostring called with unsuported type 'table'", test.f, {})
            ]])
        end)
    end)

    describe("check_exp_verify and parens", function()
        -- https://github.com/pallene-lang/pallene/issues/356
        compile([[
            function m.f(): integer
                return (1) as integer
            end
        ]])

        it("works", function()
            run_test([[ assert(1 == test.f()) ]])
        end)
    end)

    describe("the Lua stack", function()
        compile([[
            -- A function that uses a lot of stack space
            -- and needs to grow the Lua stack.
            function m.f(i: integer, sep:string): string
                if i == 0 then
                    return ""
                else
                    -- A bunch of non-constant GC variables
                    -- that live all the way to the end.
                    local x01 = "a" .. sep
                    local x02 = "b" .. sep
                    local x03 = "c" .. sep
                    local x04 = "d" .. sep
                    local x05 = "e" .. sep
                    local x06 = "f" .. sep
                    local x07 = "g" .. sep
                    local x08 = "h" .. sep
                    local x09 = "i" .. sep
                    local x10 = "j" .. sep
                    local x11 = "k" .. sep
                    local x12 = "l" .. sep
                    local x13 = "m" .. sep
                    local x14 = "n" .. sep
                    local x15 = "o" .. sep
                    local x16 = "p" .. sep
                    local x17 = "q" .. sep
                    local x18 = "r" .. sep
                    local x19 = "s" .. sep
                    local x20 = "t" .. sep
                    local x21 = "u" .. sep
                    local x22 = "v" .. sep
                    local x23 = "w" .. sep
                    local x24 = "x" .. sep
                    local x25 = "y" .. sep
                    local x26 = "z" .. sep

                    -- This function call is a garbage collection point
                    -- and should cause the vars to be saved to the stack.
                    local y = m.f(i-1, sep)

                    return (
                        y ..
                        x01 .. x02 .. x03 .. x04 .. x05 ..
                        x06 .. x07 .. x08 .. x09 .. x10 ..
                        x11 .. x12 .. x13 .. x14 .. x15 ..
                        x16 .. x17 .. x18 .. x19 .. x20 ..
                        x21 .. x22 .. x23 .. x24 .. x25 .. x26
                    )
                end
            end

            typealias func = (integer) -> (nil,nil,nil)
            function m.rets(i: integer, s:string, g:func): string
                if i == 0 then
                    return ""
                else
                    local x = s..""
                    local a,b,c = g(1)
                    local z = m.rets(i-1, s, g)
                    return x..z
                end
            end
        ]])

        it("can grow", function()
            run_test([[
                local n = 10
                local s = string.rep("abcdefghijklmnopqrstuvwxyz", n)
                assert(s == test.f(n, ""))
            ]])
        end)

        it("allocates enough space for ret values", function()
            run_test([[
                local function g() return nil,nil,nil end
                local s = string.rep("a", 64)
                assert(s == test.rets(64, "a", g))
            ]])
        end)
    end)
end

return execution_tests
