-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local mod = {}
local tagged_union = require "pallene.tagged_union"
local define_union = tagged_union.in_namespace(mod, "TagUnionTest")

describe("Typedecl", function()

    setup(function()
        define_union("Bar", {
            ABC = {"a", "b", "c"},
            DEF = {"d", "e", "f"},
        })
    end)

    it("forbids repeated tags", function()
        assert.has_error(function()
            define_union("Foo", { Bar = {"x"} })
            define_union("Foo", { Bar = {"x"} })
        end, [[tag name "TagUnionTest.Foo.Bar" is already being used]])
    end)

    it("typeof works for declared type", function ()
        assert.equals("TagUnionTest.Bar", tagged_union.typename("TagUnionTest.Bar.ABC"))
    end)

    it("typeof rejects undeclared types", function ()
        assert.equals(nil,  tagged_union.typename("TagUnionTest.Bar.LMN"))
    end)

    it("consname works for declared type", function ()
        assert.equals("ABC", tagged_union.consname("TagUnionTest.Bar.ABC"))
    end)

    it("consname rejects undeclared type", function ()
        assert.equals(nil, tagged_union.consname("TagUnionTest.Bar.LMN"))
    end)
end)
