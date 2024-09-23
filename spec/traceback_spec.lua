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

    -- Change error contents replacing numbers which most-likely to change
    err_content = err_content:gsub("%d+:", "N:"):
        gsub("%(Skipped %d+ frames%)", "(Skipped N frames)")
    assert.are.same(expected_traceback, err_content:gsub(":%d+:", ":N:"))
end

it("Rectangle", function()
    assert_test("rect", [[
pt-lua: spec/traceback/rect/main.lua:N: file spec/traceback/rect/rect.pln: line N: wrong type for downcasted value, expected float but found string
stack traceback:
    spec/traceback/rect/rect.pln:N: in function 'universal_calc_area'
    spec/traceback/rect/rect.pln:N: in function 'area'
    spec/traceback/rect/main.lua:N: in <main>
    C: in function '<?>'
]])
end)

it("Multi-module Lua", function()
    assert_test("module_lua", [[
pt-lua: spec/traceback/module_lua/main.lua:N: Any normal error from Lua!
stack traceback:
    C: in function 'error'
    spec/traceback/module_lua/main.lua:N: in function 'lua_3'
    spec/traceback/module_lua/module_lua.pln:N: in function 'pallene_2'
    spec/traceback/module_lua/main.lua:N: in function 'lua_2'
    spec/traceback/module_lua/module_lua.pln:N: in function 'pallene_1'
    spec/traceback/module_lua/main.lua:N: in function 'callback'
    ./spec/traceback/module_lua/another_module.lua:N: in function 'call_lua_callback'
    spec/traceback/module_lua/main.lua:N: in <main>
    C: in function '<?>'
]])
end)

it("Multi-module Pallene", function()
    assert_test("module_pallene", [[
pt-lua: spec/traceback/module_pallene/main.lua:N: There's an error in everyday life. Alas!
stack traceback:
    C: in function 'error'
    spec/traceback/module_pallene/main.lua:N: in function 'lua_2'
    spec/traceback/module_pallene/module_pallene_alt.pln:N: in function 'alternate_everyday_fn'
    spec/traceback/module_pallene/main.lua:N: in function 'lua_1'
    spec/traceback/module_pallene/module_pallene.pln:N: in function 'normal_everyday_fn'
    spec/traceback/module_pallene/main.lua:N: in <main>
    C: in function '<?>'
]])
end)

it("Depth recursion", function()
    assert_test("depth_recursion", [[
pt-lua: spec/traceback/depth_recursion/main.lua:N: Depth reached 0!
stack traceback:
    C: in function 'error'
    spec/traceback/depth_recursion/main.lua:N: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:N: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:N: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:N: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:N: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:N: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:N: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:N: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:N: in function 'lua_fn'
    spec/traceback/depth_recursion/depth_recursion.pln:N: in function 'pallene_fn'
    spec/traceback/depth_recursion/main.lua:N: in function 'lua_fn'
    spec/traceback/depth_recursion/main.lua:N: in <main>
    C: in function '<?>'
]])
end)

it("Stack overflow", function()
    assert_test("stack_overflow", [[
pt-lua: C stack overflow
stack traceback:
    spec/traceback/stack_overflow/stack_overflow.pln:N: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:N: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:N: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:N: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:N: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:N: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:N: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:N: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:N: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:N: in function 'please_dont_overflow'

    ... (Skipped N frames) ...

    spec/traceback/stack_overflow/stack_overflow.pln:N: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:N: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:N: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:N: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:N: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:N: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/stack_overflow.pln:N: in function 'no_overflow'
    spec/traceback/stack_overflow/main.lua:N: in function 'please_dont_overflow'
    spec/traceback/stack_overflow/main.lua:N: in <main>
    C: in function '<?>'
]])
end)

it("Anonymous lua functions", function()
    assert_test("anon_lua", [[
pt-lua: spec/traceback/anon_lua/main.lua:N: Error from an anonymous Lua fn!
stack traceback:
    C: in function 'error'
    spec/traceback/anon_lua/main.lua:N: in function '<?>'
    spec/traceback/anon_lua/anon_lua.pln:N: in function 'call_anon_lua_fn'
    spec/traceback/anon_lua/main.lua:N: in <main>
    C: in function '<?>'
]])
end)
