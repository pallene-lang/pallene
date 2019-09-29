local driver = require 'pallene.driver'
local util = require 'pallene.util'

local function run_uninitialized(code)
    assert(util.set_file_contents("test.pln", code))
    local module, errs = driver.compile_internal("test.pln", "uninitialized")
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

    teardown(function()
        os.remove("test.pln")
    end)

    it("empty function", function()
        assert_error([[
            function fn(): integer
            end
        ]], missing_return)
    end)

    it("missing return in elseif", function()
        assert_error([[
            function getval(a:integer): integer
                if a == 1 then
                    return 10
                elseif a == 2 then
                else
                    return 30
                end
            end
        ]], missing_return)
    end)

    it("catches use of uninitialized variable", function()
        assert_error([[
            function foo(): integer
                local x:integer
                return x
            end
        ]], "variable x is used before being initialized")
    end)
end)
