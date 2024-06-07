-- Copyright (c) 2024, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = require "pallene.util"

local function assert_test(test, expected_traceback)
    local plnfile = util.shell_quote("spec/traceback/"..test.."/"..test..".pln")
    local ok, err = util.execute("pallenec "..plnfile.." --use-traceback")
    assert(ok, err)

    -- Compile the second Pallene file if exists.
    local alt_plnfile = util.shell_quote("spec/traceback/"..test.."/"..test.."_alt.pln")
    local ok, _ = util.execute("test -f "..alt_plnfile)
    if ok then
        local ok, err = util.execute("pallenec "..alt_plnfile.." --use-traceback")
        assert(ok, err)
    end

    local luafile = util.shell_quote("spec/traceback/"..test.."/main.lua")
    local ok, err, _, err_content = util.outputs_of_execute("lua "..luafile)
    assert(ok, err)
    assert.are.same(expected_traceback, err_content)
end

it("Rectangle", function()
    assert_test("rect", [[
Runtime error: spec/traceback/rect/main.lua:11: file spec/traceback/rect/rect.pln: line 10: wrong type for downcasted value, expected float but found string
Stack traceback:
    spec/traceback/rect/rect.pln:10: in function 'universal_calc_area'
    spec/traceback/rect/rect.pln:13: in function 'area'
    spec/traceback/rect/main.lua:11: in function 'wrapper'
    C: in function 'xpcall'
    spec/traceback/rect/main.lua:14: in <main>
    C: in function '<?>'
]])
end)

it("Multi-module Lua", function()
    assert_test("module_lua", [[
Runtime error: spec/traceback/module_lua/main.lua:20: Any normal error from Lua!
Stack traceback:
    C: in function 'error'
    spec/traceback/module_lua/main.lua:20: in function 'lua_3'
    spec/traceback/module_lua/module_lua.pln:12: in function 'pallene_2'
    spec/traceback/module_lua/main.lua:14: in function 'lua_2'
    spec/traceback/module_lua/module_lua.pln:8: in function 'pallene_1'
    spec/traceback/module_lua/main.lua:10: in function 'callback'
    ./spec/traceback/module_lua/another_module.lua:7: in function 'call_lua_callback'
    spec/traceback/module_lua/main.lua:26: in function 'wrapper'
    C: in function 'xpcall'
    spec/traceback/module_lua/main.lua:29: in <main>
    C: in function '<?>'
]])
end)

it("Multi-module Pallene", function()
    assert_test("module_pallene", [[
Runtime error: spec/traceback/module_pallene/main.lua:10: There's an error in everyday life. Shame!
Stack traceback:
    C: in function 'error'
    spec/traceback/module_pallene/main.lua:10: in function 'lua_2'
    spec/traceback/module_pallene/module_pallene_alt.pln:8: in function 'alternate_everyday_fn'
    spec/traceback/module_pallene/main.lua:14: in function 'lua_1'
    spec/traceback/module_pallene/module_pallene.pln:8: in function 'normal_everyday_fn'
    spec/traceback/module_pallene/main.lua:20: in function 'wrapper'
    C: in function 'xpcall'
    spec/traceback/module_pallene/main.lua:23: in <main>
    C: in function '<?>'
]])
end)

it("Depth recursion", function()
    assert_test("depth_recursion", [[
Runtime error: spec/traceback/depth_recursion/main.lua:10: Depth reached 0!
Stack traceback:
    C: in function 'error'
    spec/traceback/depth_recursion/main.lua:10: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:8: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:13: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:8: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:13: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:8: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:13: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:8: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:13: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:8: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:13: in function 'lua_fn'
    spec/traceback/depth_recursion/main.lua:19: in function 'wrapper'
    C: in function 'xpcall'
    spec/traceback/depth_recursion/main.lua:22: in <main>
    C: in function '<?>'
]])
end)

