-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = require "pallene.util"

describe("pallenec", function()
    before_each(function()
        util.set_file_contents("__test__.pln", [[
            local m: module = {}
            function m.f(x:integer): integer
                return x + 17
            end
            return m
        ]])
        util.set_file_contents("__test__script__.lua", [[
            local test = require "__test__"
            print(test.f(0))
        ]])
        util.set_file_contents("__test__script__flag__.lua", [[
            local test = require "__test__flag__"
            print(test.f(0))
        ]])
    end)

    after_each(function()
        os.remove("__test__.pln")
        os.remove("__test__.c")
        os.remove("__test__.s")
        os.remove("__test__.so")
        os.remove("__test__flag__.so")
        os.remove("__test__script__.lua")
        os.remove("__test__script__flag__.lua")
    end)

    it("Can compile pallene files", function()
        assert(util.execute("./pallenec __test__.pln"))
        local ok, err, out, _ = util.outputs_of_execute("lua __test__script__.lua")
        assert(ok, err)
        assert.equals("17\n", out)
    end)

    it("Can compile with --output flag", function()
        assert(util.execute("./pallenec __test__.pln -o __test__flag__.so"))
        local ok, err, out, _ = util.outputs_of_execute("lua __test__script__flag__.lua")
        assert(ok, err)
        assert.equals("17\n", out)
    end)

    it("Can compile C files", function()
        assert(util.execute("./pallenec --emit-c __test__.pln"))
        assert(util.execute("./pallenec --compile-c __test__.c"))
        local ok, err, out, _ = util.outputs_of_execute("lua __test__script__.lua")
        assert(ok, err)
        assert.equals("17\n", out)
    end)

    it("Can create asm files", function()
        assert(util.execute("./pallenec --emit-c __test__.pln"))
        assert(util.execute("./pallenec --emit-asm __test__.c"))
        local s, err = util.get_file_contents("__test__.s")
        assert(s, err)
    end)

    it("Can detect conflicting arguments", function()
        local ok, err, _, abort_msg = util.outputs_of_execute("./pallenec --emit-c --emit-asm __test__.pln")
        assert.is_false(ok, err)
        assert(string.find(abort_msg, "Error: option '--emit-asm' can not be used together with option '--emit-c'", nil, true))
    end)
end)
