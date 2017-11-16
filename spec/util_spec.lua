local util = require "titan-compiler.util"

local function check_get_line_number(text, line_numbers)
    for i = 1, #line_numbers do
        local expected_line = line_numbers[i][1]
        local expected_col  = line_numbers[i][2]
        local line, col = util.get_line_number(text, i)
        assert.same(expected_line, line)
        assert.same(expected_col,  col)
    end
end


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
         check_get_line_number("a\nbbbbbb\n\ncde\nfghhh", {
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
        })
     end)

    it("gets line numbers from strings (no newlines in program)", function()
        check_get_line_number("abc", {
            { 1, 1 },
            { 1, 2 },
            { 1, 3 },
        })
     end)

end)
