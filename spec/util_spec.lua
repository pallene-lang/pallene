local util = require "titan-compiler.util"

describe("Titan utils", function()

     it("returns error when a file doesn't exist", function()

        local filename = "does_not_exist.titan"
        local ok, err = util.get_file_contents(filename)
        assert.falsy(ok)
        assert.matches(filename, err)

     end)

     it("writes a file to disk", function()

        local filename = "a_file.titan"
        local ok = util.set_file_contents(filename, "return {}")
        assert.truthy(ok)
        os.remove(filename)

     end)

     it("gets line numbers from strings", function()

        local text = "a\nbbbbbb\n\ncde\nfghhh"
        local lc = {
            { 1, 1 },
            { 1, 2 },
            { 2, 1 },
            { 2, 2 },
            { 2, 3 },
            { 2, 4 },
            { 2, 5 },
            { 2, 6 },
            { 2, 7 },
            { 3, 1 },
            { 4, 1 },
            { 4, 2 },
            { 4, 3 },
            { 4, 4 },
            { 5, 1 },
            { 5, 2 },
            { 5, 3 },
            { 5, 4 },
            { 5, 5 },
        }
        for i = 1, #lc do
            local l, c = util.get_line_number(text, i)
            assert.same(lc[i][1], l)
            assert.same(lc[i][2], c)
        end
     end)

    it("gets line numbers from strings (no newlines in program)", function()

        local text = "abc"
        local lc = {
            { 1, 1 },
            { 1, 2 },
            { 1, 3 },
        }
        for i = 1, #lc do
            local l, c = util.get_line_number(text, i)
            assert.same(lc[i][1], l)
            assert.same(lc[i][2], c)
        end
     end)


end)
