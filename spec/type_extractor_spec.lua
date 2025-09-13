-- Copyright (c) 2025, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local type_extractor = require "pallene.type_extractor"
local driver = require "pallene.driver"

-- Helper function to parse source code and get the AST
local function get_ast(code)
    local ast, errors = driver.compile_internal("__test__.pln", code, "typechecker")
    if not ast then
        error(string.format("Parsing error: %s", errors[1]))
    end
    return ast
end

-- Helper function to test type extraction
local function assert_type_declarations(source_code, expected_declarations)
    local ast = get_ast(source_code)
    local declarations = type_extractor.generate_type_declarations(ast)

    assert.same(expected_declarations, declarations)
end

describe("Type extractor", function()

    it("can extract type aliases for primitive types", function()
        local source = [[
            local m: module = {}

            typealias MyInt = integer
            typealias MyFloat = float
            typealias MyString = string
            typealias MyBool = boolean
            typealias MyNil = nil

            return m
        ]]

        local expected = {
            "typealias MyInt = integer",
            "typealias MyFloat = float",
            "typealias MyString = string",
            "typealias MyBool = boolean",
            "typealias MyNil = nil"
        }

        assert_type_declarations(source, expected)
    end)

    it("can extract type aliases for array types", function()
        local source = [[
            local m: module = {}

            typealias IntArray = {integer}
            typealias StringArray = {string}
            typealias NestedArray = {{integer}}

            return m
        ]]

        local expected = {
            "typealias IntArray = {integer}",
            "typealias StringArray = {string}",
            "typealias NestedArray = {{integer}}"
        }

        assert_type_declarations(source, expected)
    end)

    it("can extract type aliases for table types", function()
        local source = [[
            local m: module = {}

            typealias Point = {x: integer, y: integer}
            typealias Person = {name: string, age: integer}

            return m
        ]]

        local expected = {
            "typealias Point = {x: integer, y: integer}",
            "typealias Person = {name: string, age: integer}"
        }

        assert_type_declarations(source, expected)
    end)

    it("can extract type aliases for function types", function()
        local source = [[
            local m: module = {}

            typealias IntFunc = (integer) -> integer
            typealias MixedFunc = (integer, string) -> boolean

            return m
        ]]

        local expected = {
            "typealias IntFunc = (integer) -> integer",
            "typealias MixedFunc = (integer, string) -> boolean"
        }

        assert_type_declarations(source, expected)
    end)

    it("can extract record declarations", function()
        local source = [[
            local m: module = {}

            record Point
                x: integer
                y: integer
            end

            record Person
                name: string
                age: integer
            end

            return m
        ]]

        local expected = {
            "record Point: x: integer; y: integer",
            "record Person: name: string; age: integer"
        }

        assert_type_declarations(source, expected)
    end)

    it("should not extract local variable declarations", function()
        local source = [[
            local m: module = {}

            local counter: integer = 0
            local message: string = "Hello"

            function m.get_counter(): integer
                return counter
            end

            return m
        ]]

        local expected = {
            "get_counter: () -> integer"
        }

        assert_type_declarations(source, expected)
    end)

    it("can extract module field assignments", function()
        local source = [[
            local m: module = {}

            local counter: integer = 0

            m.counter = counter
            m.message = "Hello"

            function m.get_counter(): integer
                return counter
            end

            return m
        ]]

        local expected = {
            "counter: integer",
            "message: string",
            "get_counter: () -> integer"
        }

        assert_type_declarations(source, expected)
    end)

    it("can extract function declarations", function()
        local source = [[
            local m: module = {}

            function m.add(a: integer, b: integer): integer
                return a + b
            end

            local function greet(name: string): string
                return "Hello, " .. name
            end
            m.greet = greet

            m.double = function(x)
                return x * 2
            end as (integer) -> integer

            return m
        ]]

        local expected = {
            "add: (integer, integer) -> integer",
            "greet: (string) -> string",
            "double: (integer) -> integer"
        }

        assert_type_declarations(source, expected)
    end)

    it("can handle complex nested types", function()
        local source = [[
            local m: module = {}

            typealias Point = {x: integer, y: integer}
            typealias PointArray = {Point}

            typealias PointManager = {
                points: PointArray,
                getPoint: (integer) -> Point
            }

            return m
        ]]

        local expected = {
            "typealias Point = {x: integer, y: integer}",
            "typealias PointArray = {Point}",
            "typealias PointManager = {points: PointArray, getPoint: (integer) -> Point}"
        }

        assert_type_declarations(source, expected)
    end)

    it("can handle combinations of different declarations", function()
        local source = [[
            local m: module = {}

            typealias Point = {x: integer, y: integer}

            record Circle
                center: Point
                radius: float
            end

            function m.create_circle(x: integer, y: integer, r: float): Circle
                local p: Point = {x = x, y = y}
                local c: Circle = {center = p, radius = r}
                return c
            end

            return m
        ]]

        local expected = {
            "typealias Point = {x: integer, y: integer}",
            "record Circle: center: Point; radius: float",
            "create_circle: (integer, integer, float) -> Circle"
        }
        assert_type_declarations(source, expected)
    end)

    it("can handle higher-order functions", function()
        local source = [[
            local m: module = {}

            local function reducef(f: (float,float) -> float, init: float, arr: {float}): float
                local acc: float = init
                for i = 1, #arr do
                    acc = f(acc, arr[i])
                end
                return acc
            end

            local function reduceany(f: (any,any) -> any, init: any, arr: {any}): any
                local acc: float = init
                for i = 1, #arr do
                    acc = f(acc, arr[i])
                end
                return acc
            end

            -- function that generates a filter function
            function m.filter_gen(pred: (any) -> boolean): ({any}) -> {any}
                return function (arr)
                    local result: {any} = {}
                    for _, v in ipairs(arr) do
                        if pred(v) then
                            result[#result + 1] = v
                        end
                    end
                    return result
                end
            end


            m.reducef = reducef
            m.reduce = reduceany

            return m
        ]]

        local expected = {
            "filter_gen: ((any) -> boolean) -> ({any}) -> {any}",
            "reducef: ((float, float) -> float, float, {float}) -> float",
            "reduce: ((any, any) -> any, any, {any}) -> any",
        }

        assert_type_declarations(source, expected)
    end)

    it("should not expand type aliases in module function parameters (1)", function()
        local source = [[
            local m: module = {}

            typealias MappingI = (integer, any) -> any

            function m.imap(f: MappingI, arr: {any}): {any}
                local result: {any} = {}
                for i = 1, #arr do
                    result[i] = f(i, arr[i])
                end
                return result
            end

            return m
        ]]

        local expected = {
            "typealias MappingI = (integer, any) -> any",
            "imap: (MappingI, {any}) -> {any}",
        }

        assert_type_declarations(source, expected)
    end)

    it("should not expand type aliases in module function parameters (2)", function()
        local source = [[
            local m: module = {}

            typealias MappingI = (integer, any) -> any

            local function imap(f: MappingI, arr: {any}): {any}
                local result: {any} = {}
                for i = 1, #arr do
                    result[i] = f(i, arr[i])
                end
                return result
            end
            m.imap = imap

            return m
        ]]

        local expected = {
            "typealias MappingI = (integer, any) -> any",
            "imap: (MappingI, {any}) -> {any}",
        }

        assert_type_declarations(source, expected)
    end)

    it("should not expand type aliases in as expressions", function()
        local source = [[
            local m: module = {}

            typealias MappingI = (integer, any) -> any

            local function imap(f: MappingI, arr: {any}): {any}
                local result: {any} = {}
                for i = 1, #arr do
                    result[i] = f(i, arr[i])
                end
                return result
            end
            m.imap = imap as (MappingI, {any}) -> {any}

            return m
        ]]

        local expected = {
            "typealias MappingI = (integer, any) -> any",
            "imap: (MappingI, {any}) -> {any}",
        }

        assert_type_declarations(source, expected)
    end)

end)
