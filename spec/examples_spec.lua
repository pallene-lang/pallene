-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = require "pallene.util"

local function assert_example(example, expected_output)
    local plnfile = util.shell_quote("examples/"..example.."/"..example..".pln")
    local ok, err = util.execute("./pallenec "..plnfile)
    assert(ok, err)

    local luafile = util.shell_quote("examples/"..example.."/main.lua")
    local ok, err, output, _ = util.outputs_of_execute("./vm/src/lua "..luafile)
    assert(ok, err)
    assert.are.same(expected_output, output)
end

it("Arithmetic", function()
    assert_example("arithmetic", [[
1 + 2 = 3
1.5 - 3.25 = -1.75
]])
end)

it("Factorial", function()
    assert_example("factorial", [[
The factorial of 5 is 120.
]])
end)

it("Fibonacci", function()
    assert_example("fibonacci", [[
0
1
1
2
3
5
8
13
21
34
]])
end)

it("Rectangle", function()
    assert_example("rectangle", [[
The area of rectangle with width 10.50 and height 5.00 is 52.50
]])
end)

it("Sum of Array", function()
    assert_example("sum_of_array", [[
5.25 + 2.50 = 7.75
]])
end)
