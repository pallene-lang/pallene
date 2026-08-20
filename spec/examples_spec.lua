-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local benchlib = require "benchmarks.benchlib"
local util = require "pallene.util"

local function assert_example(example, expected_output)
    local plnfile = util.shell_quote("examples/"..example.."/"..example..".pln")
    local ok, err = util.execute("pallenec "..plnfile)
    assert(ok, err)

    local luafile = util.shell_quote("examples/"..example.."/main.lua")
    local ok, err, output, _ = util.outputs_of_execute(benchlib.PALLENE_LUA.." "..luafile)
    assert(ok, err)
    assert.are.same(expected_output, output)
end

-- For multi module examples, the dependencies need to be compiled before the dependent modules
-- so that the ".d.pln" files are available in the current directory. Hence, the `modules` argument
-- must be a list in compilation order.
local function assert_multi_module_example(example, modules, expected_output)
    local dir = util.shell_quote("examples/"..example)
    for _, module in ipairs(modules) do
        local plnfile = util.shell_quote(module..".pln")
        local ok, err = util.execute(string.format("cd %s && pallenec %s", dir, plnfile))
        assert(ok, err)
    end

    local ok, err, output, _ = util.outputs_of_execute(string.format("cd %s && lua main.lua", dir))
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

it("Matrix", function()
    assert_multi_module_example("matrix", {"vector", "matrix"}, [[
The diagonal of the square is 1.4142
Rotating pi/4 radians...
(1.0, 1.0) -> (0.0, 1.4)
(2.0, 1.0) -> (0.7, 2.1)
(2.0, 2.0) -> (0.0, 2.8)
(1.0, 2.0) -> (-0.7, 2.1)
The diagonal of the (rotated) square is 1.4142
Scaling 2x...
(0.0, 1.4) -> (0.0, 2.8)
(0.7, 2.1) -> (1.4, 4.2)
(0.0, 2.8) -> (0.0, 5.7)
(-0.7, 2.1) -> (-1.4, 4.2)
The diagonal of the square (after rotation) is 2.8284
]])
end)
