-- Copyright (c) 2024, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = require "pallene.util"

local function assert_test(test, expected_traceback)
    local plnfile = util.shell_quote("spec/traceback/"..test.."/"..test..".pln")
    local ok, err = util.execute("pallenec "..plnfile.." --use-traceback")
    assert(ok, err)

    local luafile = util.shell_quote("spec/traceback/"..test.."/main.lua")
    local ok, err, _, err_content = util.outputs_of_execute("lua "..luafile)
    assert(ok, err)
    assert.are.same(expected_traceback, err_content)
end

it("rect", function()
    assert_test("rect", [[
Runtime error: spec/traceback/rect/main.lua:9: file spec/traceback/rect/rect.pln: line 10: wrong type for downcasted value, expected float but found string
Stack traceback:
    spec/traceback/rect/rect.pln:10: in function 'universal_calc_area'
    spec/traceback/rect/rect.pln:13: in function 'area'
    spec/traceback/rect/main.lua:9: in function 'wrapper'
    C: in function 'xpcall'
    spec/traceback/rect/main.lua:12: in <main>
    C: in function '<?>'
]])
end)
