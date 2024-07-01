-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local driver = require 'pallene.driver'

local function run_uninitialized(code)
    local module, errs = driver.compile_internal("__test__.pln", code, "uninitialized")
    return module, table.concat(errs, "\n")
end

local function assert_error(code, expected_err)
    local module, errs = run_uninitialized(code)
    assert.falsy(module)
    assert.match(expected_err, errs, 1, true)
end

local missing_return =
    "control reaches end of function with non-empty return type"

describe("Uninitialized variable analysis: ", function()

    it("empty function", function()
        assert_error([[
            local m: module = {}
            function m.fn(): integer
            end
            return m
        ]], missing_return)
    end)

    it("missing return in elseif", function()
        assert_error([[
            local m: module = {}
            function m.getval(a:integer): integer
                if a == 1 then
                    return 10
                elseif a == 2 then
                else
                    return 30
                end
            end
            return m
        ]], missing_return)
    end)

    it("missing return in deep elseif", function()
        assert_error([[
            local m: module = {}
            function m.getval(a:integer): integer
                if a == 1 then
                    return 10
                elseif a == 2 then
                    return 20
                else
                    if a < 5 then
                        if a == 3 then
                            return 30
                        end
                    else
                        return 50
                    end
                end
            end
            return m
        ]], missing_return)
    end)

    it("catches use of uninitialized variable", function()
        assert_error([[
            local m: module = {}
            function m.foo(): integer
                local x:integer
                return x
            end
            return m
        ]], "variable 'x' is used before being initialized")
    end)

    it("catches use of uninitialized variable inside \"if\"", function()
        assert_error([[
            local m: module = {}
            function m.foo()
                local x:boolean
                if x  then end
            end
            return m
        ]], "variable 'x' is used before being initialized")
    end)

    it("catches use of uninitialized variable inside \"while\"", function()
        assert_error([[
            local m: module = {}
            function m.foo()
                local x:boolean
                while x do end
            end
            return m
        ]], "variable 'x' is used before being initialized")
    end)

    it("catches use of uninitialized variable inside \"repeat until\"", function()
        assert_error([[
            local m: module = {}
            function m.foo()
                local x:boolean
                repeat until x
            end
            return m
        ]], "variable 'x' is used before being initialized")
    end)

    it("catches use of uninitialized variable inside \"for\"", function()
        assert_error([[
            local m: module = {}
            function m.foo()
                local x:integer
                for i = 1, x, x do end
            end
            return m
        ]], "variable 'x' is used before being initialized")
    end)

    it("catches use of uninitialized variable inside \"for in\"", function()
        assert_error([[
            local m: module = {}
            function m.foo()
                local x:{integer}
                for i,j in ipairs(x) do end
            end
            return m
        ]], "variable 'x' is used before being initialized")
    end)

    it("catches use of uninitialized upvalue", function ()
        assert_error([[
            local m = {}
            function m.foo()
                local x: integer
                if false then x = 1 end
                local function g()
                    x = x + 1
                end
            end
            return m
        ]], "variable 'x' is used before being initialized")
    end)

    it("assumes that loops might not execute", function()
        assert_error([[
            local m: module = {}
            function m.foo(cond: boolean): integer
                local x: integer
                while cond do
                    x = 0
                    cond = x == 0
                end
                return x
            end
            return m
        ]], "variable 'x' is used before being initialized")
    end)
end)
