local c_compiler = require "titan-compiler.c_compiler"
local util = require "titan-compiler.util"

local luabase = [[
local test = require "test"
local assert = require "luassert"
]]

local function run_coder(titan_code, test_script)
    local ok, errors = c_compiler.compile("test.titan", titan_code)
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
            assert.equal(10, test.f())
            assert.is_nil(test.g)
        ]])
    end)

    it("Basic unary operations", function()
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

    -- TODO: make these not with constants, because these tests will be useless
    -- when we have constant propagation.
    it("Basic binary operations", function()
        run_coder([[
            function f(x:integer, y:integer): integer
                return x + y
            end
        ]], [[
            assert.is_equal(1 + 2, test.f(1, 2))
        ]])

        run_coder([[
            function f(x: float, y:float): float
                return x * y
            end
        ]], [[
            assert.is_equal(2.0 * 4.0, test.f(2.0, 4.0))
        ]])
    end)


end)
