local c_compiler = require "titan-compiler.c_compiler"
local util = require "titan-compiler.util"

-- TODO
-- These tests currently don't work on Travis because test_script.lua
-- cannot require luassert (due to how heredocs sets up the env vars).
--
-- So for now these tests only run if you run an set a magic environment
-- variable on your machine.
if not os.getenv("TITAN_RUN_CODER_TESTS") then
    io.stderr:write("Ignoring coder tests\n")
    return
end

local luabase = [[
local test = require "test"
local assert = require "luassert"
]]

local function run_coder(titan_code, test_script)
    local ok, errors = c_compiler.compile_titan("test.titan", titan_code)
    assert(ok, errors[1])
    util.set_file_contents("test_script.lua", luabase .. test_script)
    local ok = os.execute("./lua/src/lua test_script.lua")
    assert.truthy(ok)
end

describe("Titan coder", function()
    after_each(function()
        os.execute("rm -f test.c")
        os.execute("rm -f test.so")
        os.execute("rm -f test_script.lua")
    end)

    it("compiles an empty program", function()
        run_coder("", "")
    end)

    -- Does not export local functions
    it("Can export functions that return constants", function()
        run_coder([[
            function f(): integer
                return 10
            end

            local function g(): integer
                return 11
            end
        ]], [[
            assert.is_function(test.f)
            assert.is_nil(test.g)
        ]])
    end)

    describe("Expressions:", function()

        it("Constants", function()
            run_coder([[
                function f(): nil
                    return nil
                end
            ]], [[
                assert.is_equal(nil, test.f())
            ]])

            run_coder([[
                function f(): boolean
                    return true
                end
                function g(): boolean
                    return false
                end
            ]], [[
                assert.is_equal(true, test.f())
                assert.is_equal(false, test.g())
            ]])

            run_coder([[
                function f(): integer
                    return 17
                end
            ]], [[
                assert.is_equal(17, test.f())
            ]])

            run_coder([[
                function f(): float
                    return 3.14
                end
            ]], [[
                assert.is_equal(3.14, test.f())
            ]])
        end)

        it("Function calls (no parameters)", function()
            run_coder([[
                function f(): integer
                    return 17
                end

                function g(): integer
                    return f()
                end
            ]], [[
                assert.is_equal(17, test.g())
            ]])
        end)

        it("Function calls (one parameters)", function()
            run_coder([[
                function f(x:integer): integer
                    return x
                end

                function g(x:integer): integer
                    return f(x)
                end
            ]], [[
                assert.is_equal(17, test.g(17))
            ]])
        end)

        it("Function calls (multiple parameters)", function()
            run_coder([[
                function f(x:integer, y:integer): integer
                    return x+y
                end

                function g(x:integer, y:integer): integer
                    return f(x, y)
                end
            ]], [[
                assert.is_equal(17, test.g(16, 1))
            ]])
        end)

        it("Function calls (recursive)", function()
            run_coder([[
                function gcd(a:integer, b:integer): integer
                    if b == 0 then
                       return a
                    else
                       return gcd(b, a % b)
                    end
                end
            ]], [[
                assert.is_equal(3*5, test.gcd(2*3*5, 3*5*7))
            ]])
        end)

        describe("Vars", function()
            it("Local variables", function()
                run_coder([[
                    function f(): integer
                        local a = 1
                        local b = 1
                        do
                            local a = 0
                            b = a
                        end
                        local c = a
                        return 100*a + 10*b + c
                    end
                ]], [[
                    assert.is_equal(101, test.f())
                ]])
            end)

            it("Global variables", function()
                run_coder([[
                    local n = 0
                    function next(): integer
                        n = n + 1
                        return n
                    end
                ]], [[
                    assert.is_equal(1, test.next())
                    assert.is_equal(2, test.next())
                    assert.is_equal(3, test.next())
                ]])
            end)
        end)

        it("Unary operations", function()
            run_coder([[
                function f(x: integer): integer
                    return -x
                end
            ]], [[
                assert.is_equal(-17, test.f(17))
            ]])

            run_coder([[
                function f(x: integer): integer
                    return ~x
                end
            ]], [[
                assert.is_equal(~17, test.f(17))
            ]])

            run_coder([[
                function f(x:boolean): boolean
                    return not x
                end
            ]], [[
                assert.is_equal(not true, test.f(true))
            ]])
        end)

        it("Binary operations", function()

            -- +

            run_coder([[
                function add(x:integer, y:integer): integer
                    return x + y
                end
            ]], [[
                assert.is_equal(1 + 2, test.add(1, 2))
            ]])

            run_coder([[
                function add(x: float, y:float): float
                    return x * y
                end
            ]], [[
                assert.is_equal(2.0 * 4.0, test.add(2.0, 4.0))
            ]])

            -- -

            run_coder([[
                function sub(x:integer, y:integer): integer
                    return x - y
                end
            ]], [[
                assert.is_equal(1 - 2, test.sub(1, 2))
            ]])

            run_coder([[
                function sub(x: float, y:float): float
                    return x - y
                end
            ]], [[
                assert.is_equal(2.0 - 4.0, test.sub(2.0, 4.0))
            ]])

            -- *

            run_coder([[
                function mul(x:integer, y:integer): integer
                    return x * y
                end
            ]], [[
                assert.is_equal(2 * 3, test.mul(2, 3))
            ]])

            run_coder([[
                function mul(x: float, y:float): float
                    return x * y
                end
            ]], [[
                assert.is_equal(2.0 * 4.0, test.mul(2.0, 4.0))
            ]])

            -- /

            run_coder([[
                function div(x:integer, y:integer): float
                    return x / y
                end
            ]], [[
                assert.is_equal(1 / 2, test.div(1, 2))
            ]])

            run_coder([[
                function div(x:float, y:float): float
                    return x / y
                end
            ]], [[
                assert.is_equal(1.0 / 2.0, test.div(1.0, 2.0))
            ]])

            -- &

            run_coder([[
                function band(x:integer, y:integer): integer
                    return x & y
                end
            ]], [[
                assert.is_equal(0xf00f & 0x00ff, test.band(0xf00f, 0x00ff))
            ]])

            -- |

            run_coder([[
                function bor(x:integer, y:integer): integer
                    return x | y
                end
            ]], [[
                assert.is_equal(0xf00f | 0x00ff, test.bor(0xf00f, 0x00ff))
            ]])

            -- ~

            run_coder([[
                function bxor(x:integer, y:integer): integer
                    return x ~ y
                end
            ]], [[
                assert.is_equal(0xf00f ~ 0x00ff, test.bxor(0xf00f, 0x00ff))
            ]])

            -- <<

            run_coder([[
                function shiftl(x:integer, y:integer): integer
                    return x << y
                end
            ]], [[
                assert.is_equal(0xf0 << 1, test.shiftl(0xf0, 1))
            ]])

            -- >>

            run_coder([[
                function shiftr(x:integer, y:integer): integer
                    return x >> y
                end
            ]], [[
                assert.is_equal(0xf0 >> 1, test.shiftr(0xf0, 1))
            ]])

            -- %

            run_coder([[
                function mod(x:integer, y:integer): integer
                    return x % y
                end
            ]], [[
                assert.is_equal(10 % 3, test.mod(10, 3))
            ]])

            -- //

            run_coder([[
                function idiv(x:integer, y:integer): integer
                    return x // y
                end
            ]], [[
                assert.is_equal(10 // 3, test.idiv(10, 3))
            ]])

            run_coder([[
                function idiv(x:float, y:float): float
                    return x // y
                end
            ]], [[
                assert.is_equal(10.0 // 3.0, test.idiv(10.0, 3.0))
            ]])

            -- ^

            run_coder([[
                function pow(x:float, y:float): float
                    return x ^ y
                end
            ]], [[
                assert.is_equal(2.0 ^ 3.0, test.pow(2.0, 3.0))
            ]])

            -- ==

            run_coder([[
                function eq(x:integer, y:integer): boolean
                    return x == y
                end
            ]], [[
                assert.is_equal(0 == 1, test.eq(0, 1))
                assert.is_equal(1 == 1, test.eq(1, 1))
                assert.is_equal(1 == 0, test.eq(1, 0))
            ]])

            -- ~=

            run_coder([[
                function neq(x:integer, y:integer): boolean
                    return x ~= y
                end
            ]], [[
                assert.is_equal(0 ~= 1, test.neq(0, 1))
                assert.is_equal(1 ~= 1, test.neq(1, 1))
                assert.is_equal(1 ~= 0, test.neq(1, 0))
            ]])

            -- <

            run_coder([[
                function lt(x:integer, y:integer): boolean
                    return x < y
                end
            ]], [[
                assert.is_equal(0 < 1, test.lt(0, 1))
                assert.is_equal(1 < 1, test.lt(1, 1))
                assert.is_equal(1 < 0, test.lt(1, 0))
            ]])

            -- >

            run_coder([[
                function gt(x:integer, y:integer): boolean
                    return x > y
                end
            ]], [[
                assert.is_equal(0 > 1, test.gt(0, 1))
                assert.is_equal(1 > 1, test.gt(1, 1))
                assert.is_equal(1 > 0, test.gt(1, 0))
            ]])

            -- <=

            run_coder([[
                function le(x:integer, y:integer): boolean
                    return x <= y
                end
            ]], [[
                assert.is_equal(0 <= 1, test.le(0, 1))
                assert.is_equal(1 <= 1, test.le(1, 1))
                assert.is_equal(1 <= 0, test.le(1, 0))
            ]])

            -- >=

            run_coder([[
                function ge(x:integer, y:integer): boolean
                    return x >= y
                end
            ]], [[
                assert.is_equal(0 >= 1, test.ge(0, 1))
                assert.is_equal(1 >= 1, test.ge(1, 1))
                assert.is_equal(1 >= 0, test.ge(1, 0))
            ]])

            -- and

            run_coder([[
                function bool_and(x:boolean, y:boolean): boolean
                    return x and y
                end
            ]], [[
                assert.is_equal(true  and true,  test.bool_and(true,  true))
                assert.is_equal(true  and false, test.bool_and(true,  false))
                assert.is_equal(false and true,  test.bool_and(false, true))
                assert.is_equal(false and false, test.bool_and(false, false))
            ]])

            -- or

            run_coder([[
                function bool_or(x:boolean, y:boolean): boolean
                    return x or y
                end
            ]], [[
                assert.is_equal(true  or true,  test.bool_or(true,  true))
                assert.is_equal(true  or false, test.bool_or(true,  false))
                assert.is_equal(false or true,  test.bool_or(false, true))
                assert.is_equal(false or false, test.bool_or(false, false))
            ]])

        end)
    end)

    describe("Statements", function()

        it("Block, Assign, Decl", function()
            run_coder([[
                function f(): integer
                    local a = 1
                    local b = 2
                    do
                        local a = 3
                        b = a
                        a = b + 1
                    end
                    return a + b
                end
            ]], [[
                assert.is_equal(4, test.f())
            ]])
        end)

        it("While", function()
            run_coder([[
                function f(n: integer): integer
                    local r = 1
                    while n > 0 do
                        r = r * n
                        n = n - 1
                    end
                    return r
                end
            ]], [[
                assert.is_equal(720, test.f(6))
            ]])
        end)

        it("While", function()
            run_coder([[
                function f(n: integer): integer
                    local r = 1
                    repeat
                        r = r * n
                        n = n - 1
                    until n == 0
                    return r
                end
            ]], [[
                assert.is_equal(720, test.f(6))
            ]])
        end)

        it("If statement (with else)", function()
            run_coder([[
                function sign(x: integer) : integer
                    if x < 0 then
                        return -1
                    elseif x == 0 then
                        return 0
                    else
                        return 1
                    end
                end
            ]],[[
                assert.is_equal(-1, test.sign(-10))
                assert.is_equal( 0, test.sign(  0))
                assert.is_equal( 1, test.sign( 10))
            ]])
        end)

        it("If statement (without else)", function()
            run_coder([[
                function abs(x: integer) : integer
                    if x >= 0 then
                        return x
                    end
                    return -x
                end
            ]],[[
                assert.is_equal(10, test.abs(-10))
                assert.is_equal( 0, test.abs(  0))
                assert.is_equal(10, test.abs( 10))
            ]])
        end)

        it("For loop (integer) (going up)", function()
            run_coder([[
                function f(n: integer): integer
                    local res = 1
                    for i = 1, n do
                        res = res * i
                    end
                    return res
                end
            ]], [[
                assert.is_equal(720, test.f(6))
            ]])
        end)

        it("For loop (integer) (going down)", function()
            run_coder([[
                function f(n: integer): integer
                    local res = 1
                    for i = n, 1, -1 do
                        res = res * i
                    end
                    return res
                end
            ]], [[
                assert.is_equal(720, test.f(6))
            ]])
        end)

        it("For loop (float) (going up)", function()
            run_coder([[
                function f(n: float): float
                    local res = 1.0
                    for i = 1.0, n do
                        res = res * i
                    end
                    return res
                end
            ]], [[
                assert.is_equal(720.0, test.f(6.0))
            ]])
        end)

        it("For loop (float) (going down)", function()
            run_coder([[
                function f(n: float): float
                    local res = 1.0
                    for i = n, 1.0, -1.0 do
                        res = res * i
                    end
                    return res
                end
            ]], [[
                assert.is_equal(720.0, test.f(6.0))
            ]])
        end)

        it("Call", function()
            run_coder([[
                local i = 0

                function next(): integer
                    i = i + 1
                    return i
                end

                function f(): integer
                    next()
                    return next()
                end
            ]], [[
                assert.is_equal(2, test.f())
            ]])
        end)
    end)

    it("Can represent floating point literals perfectly accurately", function()
        run_coder([[
            function pi(): float
                return 3.141592653589793
            end
            function e(): float
                return 2.718281828459045
            end
        ]], [[
            local pi = 3.141592653589793
            local e  = 2.718281828459045
            assert.is_equal(pi, test.pi())
            assert.is_equal(e, test.e())
            assert.is_equal(pi*e*e, test.pi() * test.e() * test.e())
        ]])
    end)
end)
