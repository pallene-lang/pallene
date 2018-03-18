local util = require "titan-compiler.util"

describe("Titanc", function()
     after_each(function()
        os.execute("rm -f test.titan")
        os.execute("rm -f test.c")
        os.execute("rm -f test.so")
        os.execute("rm -f test_script.lua")
    end)

    it("Can compile titan files", function()
        util.set_file_contents("test.titan", [[
            function f(x:integer): integer
                return x + 17
            end
        ]])
        util.set_file_contents("test_script.lua", [[
            local test = require "test"
            print(test.f(0))
        ]])

        util.shell("./titanc test.titan")
        local out = util.shell("./lua/src/lua test_script.lua")
        assert.equals("17\n", out)
    end)
end)
