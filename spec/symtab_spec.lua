local symtab = require 'pallene.symtab'

describe("Titan symbol table", function()

    it("can find some symbols", function()
        local st = symtab.new()
        local d_a, d_a2, d_b = 1, 2, 3
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

