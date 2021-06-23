local util = require "pallene.util"
local execution_tests = require "spec.execution_tests"

--
-- This file tests the C backend, the main backend of the Pallene compiler.
-- However, the actual test cases are in the execution_tests.lua. Add new tests there.
-- This is because those test cases are used for both the C backend and the Lua backend.
--

local function compile_file(filename)
    local cmd = string.format("./pallenec %s", util.shell_quote(filename))
    local ok, _, _, errmsg = util.outputs_of_execute(cmd)
    assert(ok, errmsg)
end

local function compile_code(filename, pallene_code)
    assert(util.set_file_contents(filename, pallene_code))
    compile_file(filename)
end

do -- Compile modtest
    compile_file("spec/modtest.pln")
end

describe("#c_backend /", function ()
    execution_tests.run(compile_code, 'c', _ENV, false)
end)
