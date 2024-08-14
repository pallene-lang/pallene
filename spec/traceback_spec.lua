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
    local ok, _, output_content, err_content = util.outputs_of_execute("pt-lua "..luafile)
    assert(not ok, output_content)
    assert.are.same(expected_traceback, err_content)
end

it("Rectangle", function()
    assert_test("rect", [[
pt-lua: spec/traceback/rect/main.lua:8: file spec/traceback/rect/rect.pln: line 10: wrong type for downcasted value, expected float but found string
stack traceback:
    spec/traceback/rect/rect.pln:10: in function 'universal_calc_area'
    spec/traceback/rect/rect.pln:13: in function 'area'
    spec/traceback/rect/main.lua:8: in <main>
    C: in function '<?>'
]])
end)

it("Multi-module Lua", function()
    assert_test("module_lua", [[
pt-lua: spec/traceback/module_lua/main.lua:25: Any normal error from Lua!
stack traceback:
    C: in function 'error'
    spec/traceback/module_lua/main.lua:25: in function 'lua_3'
    spec/traceback/module_lua/module_lua.pln:12: in function 'pallene_2'
    spec/traceback/module_lua/main.lua:18: in function 'lua_2'
    spec/traceback/module_lua/module_lua.pln:8: in function 'pallene_1'
    spec/traceback/module_lua/main.lua:12: in function 'callback'
    ./spec/traceback/module_lua/another_module.lua:7: in function 'call_lua_callback'
    spec/traceback/module_lua/main.lua:28: in <main>
    C: in function '<?>'
]])
end)

it("Multi-module Pallene", function()
    assert_test("module_pallene", [[
pt-lua: spec/traceback/module_pallene/main.lua:11: There's an error in everyday life. Alas!
stack traceback:
    C: in function 'error'
    spec/traceback/module_pallene/main.lua:11: in function 'lua_2'
    spec/traceback/module_pallene/module_pallene_alt.pln:8: in function 'alternate_everyday_fn'
    spec/traceback/module_pallene/main.lua:16: in function 'lua_1'
    spec/traceback/module_pallene/module_pallene.pln:8: in function 'normal_everyday_fn'
    spec/traceback/module_pallene/main.lua:19: in <main>
    C: in function '<?>'
]])
end)

it("Depth recursion", function()
    assert_test("depth_recursion", [[
pt-lua: spec/traceback/depth_recursion/main.lua:11: Depth reached 0!
stack traceback:
    C: in function 'error'
    spec/traceback/depth_recursion/main.lua:11: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:8: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:14: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:8: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:14: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:8: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:14: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:8: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:14: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:8: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:14: in function 'lua_fn'
    spec/traceback/depth_recursion/main.lua:17: in <main>
    C: in function '<?>'
]])
end)

it("Stack overflow", function()
    assert_test("stack_overflow", [[
pt-lua: C stack overflow
stack traceback:
    spec/traceback/stack_overflow/stack_overflow.pln:8: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:10: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:8: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:10: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:8: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:10: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:8: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:10: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:8: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:10: in function 'please_dont_overflow'

    ... (Skipped 379 frames) ...

    spec/traceback/stack_overflow/stack_overflow.pln:8: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:10: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:8: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:10: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:8: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:10: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:8: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:10: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/main.lua:13: in <main>
    C: in function '<?>'
]])
end)

it("Anonymous lua functions", function()
    assert_test("anon_lua", [[
pt-lua: spec/traceback/anon_lua/main.lua:9: Error from an anonymous Lua fn!
stack traceback:
    C: in function 'error'
    spec/traceback/anon_lua/main.lua:9: in function '<?>'
    spec/traceback/anon_lua/anon_lua.pln:8: in function 'call_anon_lua_fn'
    spec/traceback/anon_lua/main.lua:8: in <main>
    C: in function '<?>'
]])
end)
