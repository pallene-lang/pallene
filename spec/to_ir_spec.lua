-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local driver = require "pallene.driver"
local util = require "pallene.util"

local function convert_to_ir(src)
    local module, errs = driver.compile_internal("__test__.pln", src, "ir")
    return module, table.concat(errs, "\n")
end

local function assert_error(code, expected_error)
    local module, err = convert_to_ir(util.render([[
        local m: module = {}
        $code
        return m
    ]], {
        code = code
    }))

    assert.falsy(module)
    assert.match(expected_error, err, 1, true)
end

describe("IR Generator", function()

    it("disallows too many upvalues", function()
        local t_vars = {}
        local t_captures = {}

        for i = 1, 200 do
            t_vars[i] = "local a"..i..": integer = "..i
            t_captures[i]  = "a"..i.." = ".."a"..i.." + 1"
        end

        local var_decls = table.concat(t_vars, "\n")
        local captures  = table.concat(t_captures, "\n")
        local code = util.render([[
            function m.test()
                $decls  -- 200 locals
                local f: () -> () = function ()
                    local x = 100
                    local f2: () -> () = function ()
                        $captures
                        x = x + 1 -- 201th upvalue
                    end
                end
            end
        ]], {
            decls = var_decls,
            captures = captures
        })
        assert_error(code, "too many upvalues (limit is 200)")
    end)

end)
