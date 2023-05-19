-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local tagged_union = require "pallene.tagged_union"

describe("Typedecl", function()

    setup(function()
        local foo = {}
        tagged_union.declare(foo, "foo", "Bar", {
            ABC = {"a", "b", "c"},
            DEF = {"d", "e", "f"},
        })
    end)

    it("forbids repeated tags", function()
        assert.has_error(function()
            local mod = {}
            tagged_union.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
            tagged_union.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
        end, [[tag name "TESTTYPE.Foo.Bar" is already being used]])
    end)

    it("typeof works for declared type", function ()
        assert.equals("foo.Bar", tagged_union.typename("foo.Bar.ABC"))
    end)

    it("typeof rejects undeclared types", function ()
        assert.equals(nil,  tagged_union.typename("foo.Bar.LMN"))
    end)

    it("consname works for declared type", function ()
        assert.equals("ABC", tagged_union.consname("foo.Bar.ABC"))
    end)

    it("consname rejects undeclared type", function ()
        assert.equals(nil, tagged_union.consname("foo.Bar.LMN"))
    end)
end)
