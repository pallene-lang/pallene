-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local typedecl = require "pallene.typedecl"

describe("Typedecl", function()

    setup(function()
        local foo = {}
        typedecl.declare(foo, "foo", "Bar", {
            ABC = {"a", "b", "c"},
            DEF = {"d", "e", "f"},
        })
    end)

    it("forbids repeated tags", function()
        assert.has_error(function()
            local mod = {}
            typedecl.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
            typedecl.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
        end, [[tag name "TESTTYPE.Foo.Bar" is already being used]])
    end)

    it("typeof works for declared type", function ()
        assert.equals("foo.Bar", typedecl.typename("foo.Bar.ABC"))
    end)

    it("typeof rejects undeclared types", function ()
        assert.equals(nil,  typedecl.typename("foo.Bar.LMN"))
    end)

    it("consname works for declared type", function ()
        assert.equals("ABC", typedecl.consname("foo.Bar.ABC"))
    end)

    it("consname rejects undeclared type", function ()
        assert.equals(nil, typedecl.consname("foo.Bar.LMN"))
    end)
end)
