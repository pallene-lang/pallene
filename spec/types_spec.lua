local types = require "titan-compiler.types"

describe("Titan types", function()

    it("pretty-prints types", function()
        assert.same("{ integer }", types.Array(types.Integer))
    end)

    it("checks if a type is garbage collected", function()
        assert.truthy(types.is_gc(types.String))
        assert.truthy(types.is_gc(types.Array(types.Integer)))
        assert.falsy(types.is_gc(types.Function({}, {})))
    end)

    it("checks if a type matches a tag", function()
        assert.truthy(types.has_type(types.String, "String"))
        assert.truthy(types.has_type(types.Integer, "Integer"))
    end)

end)
