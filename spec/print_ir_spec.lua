local util = require "pallene.util"
local execution_tests = require "spec.execution_tests"

local function compile(filename, pallene_code)
    assert(util.set_file_contents(filename, pallene_code))
    local cmd = string.format("./pallenec --print-ir %s", util.shell_quote(filename))
    local ok, _, _, errmsg = util.outputs_of_execute(cmd)
    assert(ok, errmsg)
end

describe("#pretty_printer /", function ()
    execution_tests.run(compile, 'pretty_printer', _ENV, true)
end)
