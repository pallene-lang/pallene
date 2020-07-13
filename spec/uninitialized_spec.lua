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
            export function fn(): integer
            end
        ]], missing_return)
    end)

    it("missing return in elseif", function()
        assert_error([[
            export function getval(a:integer): integer
                if a == 1 then
                    return 10
                elseif a == 2 then
                else
                    return 30
                end
            end
        ]], missing_return)
    end)

    it("missing return in deep elseif", function()
        assert_error([[
            export function getval(a:integer): integer
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
        ]], missing_return)
    end)

    it("catches use of uninitialized variable", function()
        assert_error([[
            export function foo(): integer
                local x:integer
                return x
            end
        ]], "variable 'x' is used before being initialized")
    end)

    it("assumes that loops might not execute", function()
        assert_error([[
            export function foo(cond: boolean): integer
                local x: integer
                while cond do
                    x = 0
                    cond = x == 0
                end
                return x
            end
        ]], "variable 'x' is used before being initialized")
    end)
end)
