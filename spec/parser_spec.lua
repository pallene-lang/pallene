local parser = require 'titan-compiler.parser'
local util = require 'titan-compiler.util'

local function assert_parse(sourcefilename)
    local source   = util.get_file_contents(sourcefilename)
    local expected = util.get_file_contents(sourcefilename..".ast")
    local ast, errors = parser.parse(source)
    local obtained
    if ast then
        obtained = parser.pretty_print_ast(ast).."\n"
    else
        error("not yet implemented")
    end
    assert.are.same(expected, obtained)
end

describe("Titan parser", function()
    
    it("can parse toplevel var declarations", function()
        assert_parse("./testfiles/toplevel_var.titan")
    end)

    it("can parse toplevel function declarations", function()
        assert_parse("./testfiles/toplevel_functions.titan")
    end)

    it("can parse types", function()
        assert_parse("./testfiles/types.titan")
    end)

    it("can parse values", function()
        assert_parse("./testfiles/values.titan")
    end)

    it("can parse table constructors", function()
        assert_parse("./testfiles/tablecons.titan")
    end)

    it("can parse statements", function()
        assert_parse("./testfiles/statements.titan")
    end)

    it("can parse return statements", function()
        assert_parse("./testfiles/return_statements.titan")
    end)

    it("return statements must be the last in the block", function()
        pending("implement syntax errors")
    end)

    it("does not allow extra semicolons after a return", function()
        pending("implement syntax errors")
    end)

    it("can parse binary and unary operators", function()
        assert_parse("./testfiles/operators.titan")
    end)

    it("can parse suffix operators", function()
        assert_parse("./testfiles/suffix.titan")
    end)

    it("only allows call expressions as statements", function()
        pending("implement syntax errors")
        -- 10
        -- x[1]
    end)

    it("can parse calls without parenthesis", function()
        assert_parse("./testfiles/string_and_table_calls.titan")
    end)

end)
