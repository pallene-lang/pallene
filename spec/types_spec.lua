-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local types = require "pallene.types"

describe("Pallene types", function()

    it("pretty-prints types", function()
        assert.same("{ integer }", types.tostring(types.T.Array(types.T.Integer)))
        assert.same("{ x: float, y: float }", types.tostring(
                types.T.Table({x = types.T.Float, y = types.T.Float})))
    end)

    it("is_gc works", function()
        assert.falsy(types.is_gc(types.T.Integer))
        assert.truthy(types.is_gc(types.T.String))
        assert.truthy(types.is_gc(types.T.Array(types.T.Integer)))
        assert.truthy(types.is_gc(types.T.Table({x = types.T.Float})))
        assert.truthy(types.is_gc(types.T.Function({}, {})))
    end)

    describe("equality", function()

        it("works for primitive types", function()
            assert.truthy(types.equals(types.T.Integer, types.T.Integer))
            assert.falsy(types.equals(types.T.Integer, types.T.String))
        end)

        it("is true for two identical tables", function()
            local t1 = types.T.Table({
                    y = types.T.Integer, x = types.T.Integer})
            local t2 = types.T.Table({
                    x = types.T.Integer, y = types.T.Integer})
            assert.truthy(types.equals(t1, t2))
            assert.truthy(types.equals(t2, t1))
        end)

        it("is false for tables with different number of fields", function()
            local t1 = types.T.Table({x = types.T.Integer})
            local t2 = types.T.Table({x = types.T.Integer,
                    y = types.T.Integer})
            local t3 = types.T.Table({x = types.T.Integer,
                    y = types.T.Integer, z = types.T.Integer})
            assert.falsy(types.equals(t1, t2))
            assert.falsy(types.equals(t2, t1))
            assert.falsy(types.equals(t2, t3))
            assert.falsy(types.equals(t3, t2))
            assert.falsy(types.equals(t1, t3))
            assert.falsy(types.equals(t3, t1))
        end)

        it("is false for tables with different field names", function()
            local t1 = types.T.Table({x = types.T.Integer})
            local t2 = types.T.Table({y = types.T.Integer})
            assert.falsy(types.equals(t1, t2))
            assert.falsy(types.equals(t2, t1))
        end)

        it("is false for tables with different field types", function()
            local t1 = types.T.Table({x = types.T.Integer})
            local t2 = types.T.Table({x = types.T.Float})
            assert.falsy(types.equals(t1, t2))
            assert.falsy(types.equals(t2, t1))
        end)

        it("is true for identical functions", function()
            local f1 = types.T.Function({types.T.String, types.T.Integer}, {types.T.Boolean})
            local f2 = types.T.Function({types.T.String, types.T.Integer}, {types.T.Boolean})
            assert.truthy(types.equals(f1, f2))
        end)

        it("is false for functions with different input types", function()
            local f1 = types.T.Function({types.T.String, types.T.Boolean}, {types.T.Boolean})
            local f2 = types.T.Function({types.T.Integer, types.T.Integer}, {types.T.Boolean})
            assert.falsy(types.equals(f1, f2))
        end)

        it("is false for functions with different output types", function()
            local f1 = types.T.Function({types.T.String, types.T.Integer}, {types.T.Boolean})
            local f2 = types.T.Function({types.T.String, types.T.Integer}, {types.T.Integer})
            assert.falsy(types.equals(f1, f2))
        end)

        it("is false for functions with different input arity", function()
            local s = types.T.String
            local f1 = types.T.Function({}, {s})
            local f2 = types.T.Function({s}, {s})
            local f3 = types.T.Function({s, s}, {s})
            assert.falsy(types.equals(f1, f2))
            assert.falsy(types.equals(f1, f3))
            assert.falsy(types.equals(f2, f1))
            assert.falsy(types.equals(f2, f3))
            assert.falsy(types.equals(f3, f1))
            assert.falsy(types.equals(f3, f2))
        end)

        it("is false for functions with different output arity", function()
            local s = types.T.String
            local f1 = types.T.Function({s}, {})
            local f2 = types.T.Function({s}, {s})
            local f3 = types.T.Function({s}, {s, s})
            assert.falsy(types.equals(f1, f2))
            assert.falsy(types.equals(f1, f3))
            assert.falsy(types.equals(f2, f1))
            assert.falsy(types.equals(f2, f3))
            assert.falsy(types.equals(f3, f1))
            assert.falsy(types.equals(f3, f2))
        end)

        it("is true for identical record types", function()
            local t = types.T.Record("P", {}, {}, false)
            assert.truthy(types.equals(t, t))
        end)

        it("is false for different record types", function()
            local t1 = types.T.Record("P", {}, {}, false)
            local t2 = types.T.Record("P", {}, {}, false)
            assert.falsy(types.equals(t1, t2))
        end)

        it("is true for similar type aliases", function()
            local ta1 = types.T.Alias("A", types.T.Integer)
            local ta2 = types.T.Alias("B", types.T.Integer)
            assert.truthy(types.equals(ta1, ta2))
        end)

        it("should expand type aliases", function()
            local ta = types.T.Alias("A", types.T.Integer)

            assert.truthy(types.equals(
                ta,
                types.T.Integer
            ))
        end)
    end)

    describe("consistency", function()
        it("allows 'any' on either side", function()
            assert.truthy(types.consistent(types.T.Any, types.T.Any))
            assert.truthy(types.consistent(types.T.Any, types.T.Integer))
            assert.truthy(types.consistent(types.T.Integer, types.T.Any))
        end)

        it("allows types with same tag", function()
            assert.truthy(types.consistent(
                types.T.Integer,
                types.T.Integer
            ))

            assert.truthy(types.consistent(
                types.T.Array(types.T.Integer),
                types.T.Array(types.T.Integer)
            ))

            assert.truthy(types.consistent(
                types.T.Array(types.T.Integer),
                types.T.Array(types.T.String)
            ))

            assert.truthy(types.consistent(
                types.T.Function({types.T.Integer}, {types.T.Integer}),
                types.T.Function({types.T.String, types.T.String}, {})
            ))
        end)

        it("forbids different tags", function()
            assert.falsy(types.consistent(
                types.T.Integer,
                types.T.String
            ))

            assert.falsy(types.consistent(
                types.T.Array(types.T.Integer),
                types.T.Function({types.T.Integer},{types.T.Integer})
            ))
        end)

        it("should be true for type aliases whose types are consistent", function()
            local ta1 = types.T.Alias("A", types.T.Any)
            local ta2 = types.T.Alias("B", types.T.Integer)
            local ta3 = types.T.Alias("C", types.T.String)

            assert.truthy(types.consistent(ta1, ta2))
            assert.truthy(types.consistent(ta1, ta3))
            assert.falsy(types.consistent(ta2, ta3))
        end)

        it("should expand type aliases", function()
            local ta = types.T.Alias("A", types.T.Integer)

            assert.truthy(types.consistent(
                ta,
                types.T.Integer
            ))

            assert.falsy(types.consistent(
                ta,
                types.T.String
            ))
        end)
    end)

    describe("type aliases", function()

        it("should recursively expand type aliases", function()
            local ta1 = types.T.Alias("A", types.T.Integer)
            local ta2 = types.T.Alias("B", ta1)
            local ta3 = types.T.Alias("C", ta2)

            assert.truthy(types.expand_typealias(ta3) == types.T.Integer)
        end)

        it("should be considered equal to the expanded type", function()
            local ta1 = types.T.Alias("A", types.T.Integer)

            assert.truthy(types.equals(
                ta1,
                types.T.Integer
            ))
        end)
    end)

end)
