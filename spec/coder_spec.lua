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
    os.execute("./lua/src/lua test_script.lua")
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
end)
