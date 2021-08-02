-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local symtab = require 'pallene.symtab'

describe("Pallene symbol table", function()

    it("can find some symbols", function()
        local st = symtab.new()
        local d_a, d_a2, d_b = { _tag = 1 }, { _tag = 2 }, { _tag = 3 }
        st:with_block(function()
            st:add_symbol("a", d_a)
            assert.are.same(st:find_symbol("a"), d_a)
            st:with_block(function()
                st:add_symbol("a", d_a2)
                st:add_symbol("b", d_b)
                assert.are.same(st:find_symbol("a"), d_a2)
                assert.are.same(st:find_symbol("b"), d_b)
            end)
            assert.are.same(st:find_symbol("a"), d_a)
            assert.are.same(st:find_symbol("b"), nil)
        end)
    end)
end)

