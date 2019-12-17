local typedecl = require "pallene.typedecl"

describe("Typedecl", function()
    it("forbids repeated tags", function()
        assert.has_error(function()
            local mod = {}
            typedecl.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
            typedecl.declare(mod, "TESTTYPE", "Foo", { Bar = {"x"} })
        end, "tag name 'TESTTYPE.Foo.Bar' is already being used")
    end)
end)
