local util = require "pallene.util"

describe("pallenec", function()
    before_each(function()
        util.set_file_contents("test.pallene", [[
            function f(x:integer): integer
                return x + 17
            end
        ]])
        util.set_file_contents("test_script.lua", [[
            local test = require "test"
            print(test.f(0))
        ]])
    end)

    after_each(function()
        os.remove("test.pallene")
        os.remove("test.c")
        os.remove("test.s")
        os.remove("test.so")
        os.remove("test_script.lua")
    end)

    it("Can compile titan files", function()
        util.shell("./pallenec test.pallene")
        local out = util.shell("./lua/src/lua test_script.lua")
        assert.equals("17\n", out)
    end)

    it("Can compile C files", function()
        util.shell("./pallenec --emit-c test.pallene")
        util.shell("./pallenec --compile-c test.c")
        local out = util.shell("./lua/src/lua test_script.lua")
        assert.equals("17\n", out)
    end)

    it("Can create asm files", function()
        util.shell("./pallenec --emit-c test.pallene")
        util.shell("./pallenec --emit-asm test.c")
        local s, err = util.get_file_contents("test.s")
        assert(s, err)
    end)
end)
