local util = require "pallene.util"

describe("pallenec", function()
    before_each(function()
        util.set_file_contents("test.pln", [[
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
        os.remove("test.pln")
        os.remove("test.c")
        os.remove("test.s")
        os.remove("test.so")
        os.remove("test_script.lua")
    end)

    it("Can compile pallene files", function()
        assert(util.execute("./pallenec test.pln"))
        local ok, err, out, _ = util.outputs_of_execute("./lua/src/lua test_script.lua")
        assert(ok, err)
        assert.equals("17\n", out)
    end)

    it("Can compile C files", function()
        assert(util.execute("./pallenec --emit-c test.pln"))
        assert(util.execute("./pallenec --compile-c test.c"))
        local ok, err, out, _ = util.outputs_of_execute("./lua/src/lua test_script.lua")
        assert(ok, err)
        assert.equals("17\n", out)
    end)

    it("Can create asm files", function()
        assert(util.execute("./pallenec --emit-c test.pln"))
        assert(util.execute("./pallenec --emit-asm test.c"))
        local s, err = util.get_file_contents("test.s")
        assert(s, err)
    end)

    it("Can detect conflicting arguments", function()
        local ok, err, out, abortMssg = util.outputs_of_execute("./pallenec --emit-c --emit-asm test.pln")
        assert.is_false(ok, err)
        assert.equals("./pallenec: flags --emit-c and --emit-asm are mutually exclusive\n", abortMssg)
    end)
end)
