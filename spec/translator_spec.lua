-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- The expected translations contain spaces, which is what the translator is expected to do when
-- removing type annotations. Please do not delete them, otherwise the tests will fail.

local util = require "pallene.util"
local execution_tests = require "spec.execution_tests"

local function compile(filename, pallene_code, preserve_columns)
    assert(util.set_file_contents(filename, pallene_code))
    local flag = "--emit-lua"
    if preserve_columns then
        flag = "--emit-lua-preserve-columns"
    end
    local cmd = string.format("pallenec %s " .. flag, util.shell_quote(filename))
    local ok, _, _, error_message = util.outputs_of_execute(cmd)
    return ok, error_message
end

------------------
-- Execution tests
-------------------

local function execution_compile(filename, pallene_code)
    return assert(compile(filename, pallene_code))
end

describe("#lua_backend /", function ()
    execution_tests.run(execution_compile, 'lua', _ENV, false)
end)

--------------------
-- Translation tests
--------------------

local function assert_translation(pallene_code, expected, preserve_columns)
    assert(compile("__translation_test__.pln", pallene_code, preserve_columns))
    local contents = assert(util.get_file_contents("__translation_test__.lua"))
    -- The introduction of math.ln in Pallene to workaround single param math.log requires emitted
    -- Lua code to handle this as well. The current workaround injects "math.ln = math.log; " at
    -- the beginning of the emited Lua. This function needs to account for this injection.
    expected = "math.ln = math.log; " .. expected
    assert.are.same(expected, contents)
end

local function assert_translation_error(pallene_code, expected)
    local ok, err = compile("__translation_test__.pln", pallene_code)
    assert.is_false(ok)
    assert.match(expected, err, 1, true)
end

local function cleanup()
    os.remove("__translation_test__.pln")
    os.remove("__translation_test__.lua")
end

describe("Pallene to Lua translator / #translator", function ()
    teardown(cleanup)

    it("Missing end keyword in function definition (syntax error)", function ()
        assert_translation_error([[
            local m = {}
            local function f(): integer
        ]],
        "expected 'end' before end of the file, to close the 'function'")
    end)

    it("Unknown type (semantic error)", function ()
        assert_translation_error([[
            local m = {}
            local function f() : unknown
            end
            return m
        ]],
        "type 'unknown' is not declared")
    end)

    it("copy the program as is when there are no type annotations", function ()
        assert_translation(
[[
local m: module = {}
local i = 10
local function print_hello()
    -- This is a comment.
    -- This is another line comment.
    io.write("Hello, world!")
end
return m
]],
[[
local m = {}
local i = 10
local function print_hello()
    -- This is a comment.
    -- This is another line comment.
    io.write("Hello, world!")
end
return m
]])
    end)

    it("Remove #type annotations from a top-level variable", function ()
        assert_translation(
[[
local m: module = {}
local xs: integer = 10
return m
]],
[[
local m = {}
local xs = 10
return m
]])
    end)

    it("Remove #type annotations from top-level variables", function ()
        assert_translation(
[[
local m: module = {}
local a: integer, b: integer, c: string = 5, 3, 'Marshall Mathers'
return m
]],
[[
local m = {}
local a, b, c = 5, 3, 'Marshall Mathers'
return m
]])
    end)

    it("Keep newlines that appear after the colon in a top-level variable type annotation", function ()
        assert_translation(
[[
local m: module = {}
local xs:
    integer = 10
return m
]],
[[
local m = {}
local xs
 = 10
return m
]])
    end)

    it("Keep newlines that appear inside a top-level variable type annotation", function ()
        assert_translation(
[[
local m: module = {}
local a: {
    integer
} = { 5, 3, 19 }
return m
]],
[[
local m = {}
local a

 = { 5, 3, 19 }
return m
]])
    end)

    it("Keep tabs that appear in a top-level variable type annotation", function ()
        assert_translation(
            "local m: module = {} local xs:\tinteger = 10\treturn m",
            "local m = {} local xs = 10\treturn m")
    end)

    it("Keep return carriages that appear in a top-level variable type annotation", function ()
        assert_translation(
            "local m: module = {} local xs:\rinteger = 10\treturn m\n",
            "local m = {} local xs\r = 10\treturn m\n")
    end)

    it("Keep newlines that appear after colons in top-level variable type annotations", function ()
        assert_translation(
[[
local m: module = {}
local a:
    integer, b:
        string, c:
            integer = 53, 'Madyanam', 19
return m
]],
[[
local m = {}
local a
, b
, c
 = 53, 'Madyanam', 19
return m
]])
    end)

    it("Keep comments that appear after the colon in a top-level variable type annotation", function ()
        assert_translation(
[[
local m: module = {}
local xs: -- This is a comment.
    integer = 10
return m
]],
[[
local m = {}
local xs-- This is a comment.
 = 10
return m
]])
    end)

    it("Keep comments that appear outside type annotations", function ()
        assert_translation([[
-- Knock knock
local m: module = {}
local x: { -- Who's there?
    integer -- Baby Yoda
} = { 5, 3, 19 } -- Baby Yoda who?
-- Baby Yoda one for me. XD
local xs: { -- This is a comment.
    integer -- This is another comment.
} = { 5, 3, 19 }
return m
]],
[[
-- Knock knock
local m = {}
local x-- Who's there?
-- Baby Yoda
 = { 5, 3, 19 } -- Baby Yoda who?
-- Baby Yoda one for me. XD
local xs-- This is a comment.
-- This is another comment.
 = { 5, 3, 19 }
return m
]])
    end)

    it("Keep comments that appear inside in a top-level variable type annotation", function ()
        assert_translation(
[[
local m: module = {}
local xs: { -- This is a comment.
    integer -- This is another comment.
} = { 5, 3, 19 }
return m
]],
[[
local m = {}
local xs-- This is a comment.
-- This is another comment.
 = { 5, 3, 19 }
return m
]])
    end)

    it("Remove type annotations from top-level function parameters", function ()
        assert_translation(
[[
local m: module = {}
local function f(x: integer, y: integer)
end
return m
]],
[[
local m = {}
local function f(x, y)
end
return m
]])
    end)

    it("Remove type annotations from local variable declarations", function ()
        assert_translation(
[[
local m: module = {}
local function f()
    local i: integer = 5
end
return m
]],
[[
local m = {}
local function f()
    local i = 5
end
return m
]])
    end)

    it("Remove type annotations when multiple variables are declared together", function ()
        assert_translation(
[[
local m: module = {}
local function f()
    local a: string, m: string = "preets", "yoda"
end
return m
]],
[[
local m = {}
local function f()
    local a, m = "preets", "yoda"
end
return m
]])
    end)

    it("Remove type annotations when multiple variables are declared together", function ()
        assert_translation(
[[
local m: module = {}
local function f()
    local a, m: string = "preets", "yoda"
end
return m
]],
[[
local m = {}
local function f()
    local a, m = "preets", "yoda"
end
return m
]])
    end)

    it("Remove simple type aliases", function ()
        assert_translation(
[[
local m: module = {}
local function a()
end

typealias int = integer

local function b()
end
return m
]],
[[
local m = {}
local function a()
end



local function b()
end
return m
]])
    end)

    it("Remove multiline type aliases", function ()
        assert_translation(
[[
local m: module = {}
local function a()
end

typealias point = {
    x: integer,
    y: integer
}

local function b()
end
return m
]],
[[
local m = {}
local function a()
end






local function b()
end
return m
]])
    end)

    it("Remove records", function ()
        assert_translation(
[[
local m: module = {}
local function a()
end

record Point
    x: integer
    y: integer
end

local function b()
end
return m
]],
[[
local m = {}
local function a()
end






local function b()
end
return m
]])
    end)

    it("Remove return type", function ()
        assert_translation(
[[
local m: module = {}
local function a(): integer
    return 0
end
return m
]],
[[
local m = {}
local function a()
    return 0
end
return m
]])
    end)

    it("Remove return types", function ()
        assert_translation(
[[
local m: module = {}
local function a(): ( integer, string )
    return 0, "Kush"
end
return m
]],
[[
local m = {}
local function a()
    return 0, "Kush"
end
return m
]])
    end)

    it("Mutually recursive functions (infinite)", function ()
        assert_translation(
[[
local m: module = {}
local a, b
function a()
    b()
end
function b()
    a()
end
return m
]],
[[
local m = {}
local a, b
function a()
    b()
end
function b()
    a()
end
return m
]]
)
    end)

    it("Remove any type annotation", function ()
        assert_translation(
[[
local m: module = {}
local xs: {any} = {10, "hello", 3.14}

local function f(x: any, y: any): any
    return nil as nil
end

return m
]],
[[
local m = {}
local xs = {10, "hello", 3.14}

local function f(x, y)
    return nil
end

return m
]])
    end)

    it("Remove any type annotation (preserving columns)", function ()
        assert_translation(
[[
local m: module = {}
local xs: {any} = {10, "hello", 3.14}

local function f(x: any, y: any): any
    return nil as nil
end

return m
]],
[[
local m         = {}
local xs        = {10, "hello", 3.14}

local function f(x     , y     )     
    return nil       
end

return m
]], true)
    end)

    it("Remove function shapes", function ()
        assert_translation(
[[
local m: module = {}
local function invoke(x: (integer, integer) -> (float, float)): (float, float)
    return x(1, 2)
end
return m
]],
[[
local m = {}
local function invoke(x)
    return x(1, 2)
end
return m
]])
    end)

    it("Remove casts from initializer list", function ()
        assert_translation(
[[
local m: module = {}
typealias point = {
    x: integer,
    y: integer
}
local i: any = 1
local p: point = { x = i as integer, y = i as integer }
return m
]],
[[
local m = {}




local i = 1
local p = { x = i, y = i }
return m
]])
    end)

    it("Remove casts from toplevel variables", function ()
        assert_translation(
[[
local m: module = {}
local i: any = 1
local j: integer = i as integer
return m
]],
[[
local m = {}
local i = 1
local j = i
return m
]])
    end)

    it("Remove redundant casts from toplevel variables", function ()
        assert_translation(
[[
local m: module = {}
local i: any = 1
local j: integer = i as integer
local k: integer = (j as integer) + 1
return m
]],
[[
local m = {}
local i = 1
local j = i
local k = (j) + 1
return m
]])
    end)

    it("Remove casts from if condition", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    if k as boolean then
    end
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    if k then
    end
end
return m
]])
    end)

    it("Remove casts from if body", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    if true then
        local j: boolean = k as boolean
    end
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    if true then
        local j = k
    end
end
return m
]])
    end)

    it("Remove casts from else if condition", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    if false then
        -- Nothing
    elseif k as boolean then
        -- Nothing
    end
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    if false then
        -- Nothing
    elseif k then
        -- Nothing
    end
end
return m
]])
    end)

    it("Remove casts from else if body", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    if false then
        -- Nothing
    elseif true then
        local j: integer = k as integer
    end
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    if false then
        -- Nothing
    elseif true then
        local j = k
    end
end
return m
]])
    end)

    it("Remove casts from else body", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    if false then
        -- Nothing
    else
        local j: integer = k as integer
    end
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    if false then
        -- Nothing
    else
        local j = k
    end
end
return m
]])
    end)

    it("Remove casts from repeat condition", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    repeat
        -- Nothing
    until k as boolean
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    repeat
        -- Nothing
    until k
end
return m
]])
    end)

    it("Remove casts from repeat body", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    repeat
        local j: integer = k as integer
    until true
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    repeat
        local j = k
    until true
end
return m
]])
    end)

    it("Remove casts from for expressions", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    for j: integer = k as integer, k as integer + 10, k as integer do
        -- Nothing
    end
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    for j = k, k + 10, k do
        -- Nothing
    end
end
return m
]])
    end)

    it("Remove casts from for body", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    for j: integer = 1, 10 do
        local m: integer = k as integer
    end
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    for j = 1, 10 do
        local m = k
    end
end
return m
]])
    end)

    it("Remove casts from assignments", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    k, k = k as integer, k as boolean
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    k, k = k, k
end
return m
]])
    end)

    it("Remove casts in nested casts", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    k = ((k as integer) as integer)
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    k = ((k))
end
return m
]])
    end)

    it("Remove casts from local variable declarations", function ()
        assert_translation(
[[
local m: module = {}
local k: any = 1

local function f()
    local j: integer = k as integer
end
return m
]],
[[
local m = {}
local k = 1

local function f()
    local j = k
end
return m
]])
    end)

    it("Remove casts from function calls", function ()
        assert_translation(
[[
local m: module = {}
local k: any = "Madyanam"

local function f()
    io.write(k as string)
end
return m
]],
[[
local m = {}
local k = "Madyanam"

local function f()
    io.write(k)
end
return m
]])
    end)

    it("Remove casts from function calls", function ()
        assert_translation(
[[
local m: module ={}
local name1: any = "Anushka"
local name2: any = "Samuel"

local function get_names(): (string, string)
    return name1 as string, name2 as string
end
return m
]],
[[
local m ={}
local name1 = "Anushka"
local name2 = "Samuel"

local function get_names()
    return name1, name2
end
return m
]])
    end)

    it("Keep the strings quotes as is", function ()
        assert_translation(
[[
local m: module = {}
local function print_hello()
    io.write('Hello, ')
    io.write("world!")
end
return m
]],
[[
local m = {}
local function print_hello()
    io.write('Hello, ')
    io.write("world!")
end
return m
]])
    end)

    it("Remove return type annotations", function ()
        assert_translation(
[[
local m: module = {}
local function get_numbers(): ( integer, integer )
    return 53, 519
end
return m
]],
[[
local m = {}
local function get_numbers()
    return 53, 519
end
return m
]])
    end)

    it("Remove parameter and return type annotations", function ()
        assert_translation(
[[
local m: module = {}
local function add(x: integer, y: integer): integer
    return x + y
end
return m
]],
[[
local m = {}
local function add(x, y)
    return x + y
end
return m
]])
    end)

    it("Remove local variable type annotations.", function ()
        assert_translation(
[[
local m: module = {}
local function f()
    local x: integer = 10
    local y: integer = 20
    local z: integer = x + y
end
return m
]],
[[
local m = {}
local function f()
    local x = 10
    local y = 20
    local z = x + y
end
return m
]])
    end)

    it("Expressions are copied as is", function ()
        assert_translation(
[[
local m: module = {}
local x = (1 + 2) * (100 / 30)
return m
]],
[[
local m = {}
local x = (1 + 2) * (100 / 30)
return m
]])
    end)

    it("While statements", function ()
        assert_translation(
[[
local m: module = {}
local function count()
    local i: integer = 1
    while i <= 10 do
        i = i + 1
    end
end
return m
]],
[[
local m = {}
local function count()
    local i = 1
    while i <= 10 do
        i = i + 1
    end
end
return m
]])
    end)

    it("Do Statement", function ()
        assert_translation(
[[
local m: module = {}
local function f()
    local i: integer = 10
    do
        local i: integer = 20
    end
end
return m
]],
[[
local m = {}
local function f()
    local i = 10
    do
        local i = 20
    end
end
return m
]])
    end)

    it("If statement", function ()
        assert_translation(
[[
local m: module = {}
local function is_even(n: integer): boolean
    if (n % 2) == 0 then
        return true
    else
        return false
    end
end
return m
]],
[[
local m = {}
local function is_even(n)
    if (n % 2) == 0 then
        return true
    else
        return false
    end
end
return m
]])
    end)

    it("For statement", function ()
        assert_translation(
[[
local m: module = {}
local function f()
    for i: integer = 1, 10 do
    end
end
return m
]],
[[
local m = {}
local function f()
    for i = 1, 10 do
    end
end
return m
]])
    end)
end)
