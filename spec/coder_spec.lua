local util = require "pallene.util"
local execution_tests = require "spec.execution_tests"

local function compile(filename, pallene_code)
    assert(util.set_file_contents(filename, pallene_code))
    local cmd = string.format("./pallenec %s", util.shell_quote(filename))
    local ok, _, out, errmsg = util.outputs_of_execute(cmd)
    print(out)
    assert(ok, errmsg)
end

describe("#c_backend /", function ()
    execution_tests.run(compile, 'c', _ENV, false)
end)
