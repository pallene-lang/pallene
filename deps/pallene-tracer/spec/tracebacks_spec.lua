-- Copyright (c) 2024, The Pallene Developers
-- Pallene Tracer is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = require "spec.util"

local function assert_test(example, expected_content)
    assert(util.execute("make --quiet tests"))

    local dir  = util.shell_quote("spec/tracebacks/"..example)
    local ok, _, output_content, err_content =
        util.outputs_of_execute("./pt-lua "..dir.."/main.lua")
    assert(not ok, output_content)
    assert.are.same(expected_content, err_content)
end

it("Dispatch", function()
    assert_test("dispatch", [[
./pt-lua: spec/tracebacks/dispatch/main.lua:9: Error from a C function, which has no trace in Lua callstack!
stack traceback:
    spec/tracebacks/dispatch/module.c:48: in function 'some_oblivious_c_function'
    spec/tracebacks/dispatch/module.c:92: in function 'module_fn_2'
    spec/tracebacks/dispatch/main.lua:9: in function 'lua_callee_1'
    spec/tracebacks/dispatch/module.c:61: in function 'module_fn_1'
    spec/tracebacks/dispatch/main.lua:12: in <main>
    C: in function '<?>'
]])
end)

it("Singular", function()
    assert_test("singular", [[
./pt-lua: spec/tracebacks/singular/main.lua:9: Life's !good
stack traceback:
    spec/tracebacks/singular/module.c:49: in function 'lifes_good_fn'
    spec/tracebacks/singular/module.c:59: in function 'singular_fn'
    spec/tracebacks/singular/main.lua:9: in function 'some_lua_fn'
    spec/tracebacks/singular/main.lua:12: in <main>
    C: in function '<?>'
]])
end)


it("Multi-module", function()
    assert_test("multimod", [[
./pt-lua: spec/tracebacks/multimod/main.lua:10: Error from another module!
stack traceback:
    spec/tracebacks/multimod/module_b.c:19: in function 'another_mod_fn'
    spec/tracebacks/multimod/main.lua:10: in function 'some_lua_fn'
    spec/tracebacks/multimod/module_a.c:20: in function 'some_mod_fn'
    spec/tracebacks/multimod/main.lua:13: in <main>
    C: in function '<?>'
]])
end)

it("Depth recursion", function()
    assert_test("depth_recursion", [[
./pt-lua: spec/tracebacks/depth_recursion/main.lua:10: Depth reached 0!
stack traceback:
    C: in function 'error'
    spec/tracebacks/depth_recursion/main.lua:10: in function 'lua_fn'
    spec/tracebacks/depth_recursion/module.c:56: in function 'module_fn'
    spec/tracebacks/depth_recursion/main.lua:13: in function 'lua_fn'
    spec/tracebacks/depth_recursion/module.c:56: in function 'module_fn'
    spec/tracebacks/depth_recursion/main.lua:13: in function 'lua_fn'
    spec/tracebacks/depth_recursion/module.c:56: in function 'module_fn'
    spec/tracebacks/depth_recursion/main.lua:13: in function 'lua_fn'
    spec/tracebacks/depth_recursion/module.c:56: in function 'module_fn'
    spec/tracebacks/depth_recursion/main.lua:13: in function 'lua_fn'
    spec/tracebacks/depth_recursion/module.c:56: in function 'module_fn'
    spec/tracebacks/depth_recursion/main.lua:13: in function 'lua_fn'
    spec/tracebacks/depth_recursion/main.lua:16: in <main>
    C: in function '<?>'
]])
end)

it("Anonymous Lua Fn", function()
    assert_test("anon_lua", [[
./pt-lua: spec/tracebacks/anon_lua/main.lua:9: Error from a C function, which has no trace in Lua callstack!
stack traceback:
    spec/tracebacks/anon_lua/module.c:48: in function 'some_oblivious_c_function'
    spec/tracebacks/anon_lua/module.c:92: in function 'module_fn_2'
    spec/tracebacks/anon_lua/main.lua:9: in function '<?>'
    spec/tracebacks/anon_lua/module.c:61: in function 'module_fn_1'
    spec/tracebacks/anon_lua/main.lua:12: in <main>
    C: in function '<?>'
]])
end)

it("Traceback Ellipsis", function()
    assert_test("ellipsis", [[
./pt-lua: C stack overflow
stack traceback:
    spec/tracebacks/ellipsis/module.c:52: in function 'module_fn'
    spec/tracebacks/ellipsis/main.lua:9: in function 'lua_fn'
    spec/tracebacks/ellipsis/module.c:52: in function 'module_fn'
    spec/tracebacks/ellipsis/main.lua:9: in function 'lua_fn'
    spec/tracebacks/ellipsis/module.c:52: in function 'module_fn'
    spec/tracebacks/ellipsis/main.lua:9: in function 'lua_fn'
    spec/tracebacks/ellipsis/module.c:52: in function 'module_fn'
    spec/tracebacks/ellipsis/main.lua:9: in function 'lua_fn'
    spec/tracebacks/ellipsis/module.c:52: in function 'module_fn'
    spec/tracebacks/ellipsis/main.lua:9: in function 'lua_fn'

    ... (Skipped 379 frames) ...

    spec/tracebacks/ellipsis/module.c:52: in function 'module_fn'
    spec/tracebacks/ellipsis/main.lua:9: in function 'lua_fn'
    spec/tracebacks/ellipsis/module.c:52: in function 'module_fn'
    spec/tracebacks/ellipsis/main.lua:9: in function 'lua_fn'
    spec/tracebacks/ellipsis/module.c:52: in function 'module_fn'
    spec/tracebacks/ellipsis/main.lua:9: in function 'lua_fn'
    spec/tracebacks/ellipsis/module.c:52: in function 'module_fn'
    spec/tracebacks/ellipsis/main.lua:9: in function 'lua_fn'
    spec/tracebacks/ellipsis/main.lua:12: in <main>
    C: in function '<?>'
]])
end)
