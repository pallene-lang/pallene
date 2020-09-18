local typedecl = require "pallene.typedecl"

describe("Typedecl", function()
    it("forbids repeated tags", function()
        assert.has_error(function()
            local mod = {}
            typedecl.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
            typedecl.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
        end, "tag name 'TESTTYPE.Foo.Bar' is already being used")
    end)

    it("'match_tag' works as expected.", function ()
        assert.falsy(typedecl.match_tag("foo.Bar.baz", "f.o.Bar"))
        assert.truthy(typedecl.match_tag("foo.Bar.baz", "foo.Bar"))
        assert.falsy(typedecl.match_tag("types.T.Float", "types.T."))
    end, "")
end)
