local symtab = require 'titan-compiler.symtab'

describe("Titan symbol table", function()

    it("can find some symbols", function()
        local st = symtab.new()
        local d_a, d_a2, d_b = 1, 2, 3
        st:open_block()
        st:add_symbol("a", d_a)
        assert.are.same(st:find_symbol("a"), d_a)
        st:open_block()
            st:add_symbol("a", d_a2)
            st:add_symbol("b", d_b)
            assert.are.same(st:find_symbol("a"), d_a2)
            assert.are.same(st:find_symbol("b"), d_b)
        st:close_block() 
        assert.are.same(st:find_symbol("a"), d_a)
        assert.are.same(st:find_symbol("b"), nil)
        st:close_block() 
    end)
end)

