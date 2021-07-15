-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local typedecl = require "pallene.typedecl"

describe("Typedecl", function()
    it("forbids repeated tags", function()
        assert.has_error(function()
            local mod = {}
            typedecl.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
            typedecl.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
        end, "tag name 'TESTTYPE.Foo.Bar' is already being used")
    end)

    describe("match_tag", function ()
        it("returns the tag name", function ()
            assert.equals("baz", typedecl.match_tag("foo.Bar.baz", "foo.Bar"))
        end)

        it("doesn't crash with a non-string tag", function()
            assert.equals(false, typedecl.match_tag(nil, "types.T"))
        end)

        it("doesn't treat a '.' in the prefix string as regex", function ()
            assert.equals(false, typedecl.match_tag("foo.Bar.baz", "f.o.Bar"))
        end)

        it("doesn't require a '.' at the end of prefix.", function ()
            assert.equals(false, typedecl.match_tag("types.T.Float", "types.T."))
        end)
    end)
end)
