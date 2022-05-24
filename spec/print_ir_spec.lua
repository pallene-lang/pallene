-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = require "pallene.util"
local execution_tests = require "spec.execution_tests"

local function compile(filename, pallene_code)
    assert(util.set_file_contents(filename, pallene_code))
    local cmd = string.format("pallenec --print-ir %s", util.shell_quote(filename))
    local ok, _, result, errmsg = util.outputs_of_execute(cmd)
    assert(ok, errmsg)
    assert(string.match(result, 'function main'))
end

describe("#pretty_printer /", function ()
    execution_tests.run(compile, 'pretty_printer', _ENV, true)
end)
