local util = require "pallene.util"

local function compile(pallene_code)
    setup(function ()
        assert(util.set_file_contents("__test__.pln", pallene_code))
        local ok, _, _, error_message = util.outputs_of_execute("./pallenec __test__.pln --emit-lua")
        if not ok then error(error_message) end
    end)
end

local function assert_translation(description, pallene_code, expected)
    compile(pallene_code)
    it(description, function()
        local contents = assert(util.get_file_contents("__test__.lua"))
        assert.are.same(expected, contents)
    end)
end

local function cleanup()
    os.remove("__test__.pln")
    os.remove("__test__.lua")
end

describe("Pallene to Lua translator", function ()
    teardown(cleanup)

    describe("empty program", function ()
        compile("")
        it("results in an empty result", function() end)
    end)

    describe("hello world", function ()
        assert_translation("copies the input to the output file as is",
            [[
                function print(text: string)
                    io.write(text .. "\n")
                end
            ]],
            [[
                function print(text: string)
                    io.write(text .. "\n")
                end
            ]])
    end)
end)