local util = require "pallene.util"
local execution_tests = require "spec.execution_tests"

local function compile(filename, pallene_code)
    setup(function()
        assert(util.set_file_contents(filename, pallene_code))
        local cmd = string.format("./pallenec %s", util.shell_quote(filename))
        local ok, _, _, errmsg = util.outputs_of_execute(cmd)
        if not ok then
            error(errmsg)
        end
    end)

    it("does not crash the #prettyprinter", function()
        local cmd = string.format("./pallenec --print-ir %s", util.shell_quote(filename))
        local ok, _, _, errmsg = util.outputs_of_execute(cmd)
        if not ok then error(errmsg) end
    end)
end

describe("#c_backend /", function ()
    execution_tests.run(compile, 'c', _ENV)
end)
