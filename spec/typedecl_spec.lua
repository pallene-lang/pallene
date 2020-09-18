local typedecl = require "pallene.typedecl"

describe("Typedecl", function()
    it("forbids repeated tags", function()
        assert.has_error(function()
            local mod = {}
            typedecl.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
            typedecl.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
        end, "tag name 'TESTTYPE.Foo.Bar' is already being used")
    end)

    describe("'match_tag'", function ()
        it("doesn't treat a '.' in the prefix string as regex", function ()
            assert.falsy(typedecl.match_tag("foo.Bar.baz", "f.o.Bar"))
        end)

        it("works as expected with input strings", function ()
            assert.are.equals(typedecl.match_tag("foo.Bar.baz", "foo.Bar"), "baz")
        end)

        it("doesn't require a '.' at the end of prefix.", function ()
            assert.falsy(typedecl.match_tag("types.T.Float", "types.T."))
        end)
    end)

end)
