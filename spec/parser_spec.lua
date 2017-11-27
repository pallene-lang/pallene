local parser = require 'titan-compiler.parser'
local util = require 'titan-compiler.util'

-- Return a version of t2 that only contains fields present in t1 (recursively)
-- Example:
--   t1  = { b = { c = 10 } e = 40 }
--   t2  = { a = 1, b = { c = 20, d = 30} }
--   out = { b = { c = 20 } }
local function restrict(t1, t2)
    if type(t1) == 'table' and type(t2) == 'table' then
        local out = {}
        for k,_ in pairs(t1) do
            out[k] = restrict(t1[k], t2[k])
        end
        return out
    else
        return t2
    end
end

local function parse_file(filename)
    local input = assert(util.get_file_contents(filename))
    return parser.parse(input)
end

-- To avoid having these tests break all the time when we make insignificant
-- changes to the AST, we only verify a subset of the AST.
local function assert_ast(program, expected)
    local received = restrict(expected, program)
    assert.are.same(expected, received)
end

describe("Titan parser", function()

    it("can parse empty files with just whitespace and comments", function()
        local program, err = parse_file("./testfiles/just_spaces.titan")
        assert.truthy(program)
        assert_ast(program, {})
    end)

    it("can parse toplevel var declarations", function()
        local program, err = parse_file("./testfiles/toplevel_var.titan")
        assert.truthy(program)
        assert_ast(program, {
            { _tag = "TopLevel_Var",
                islocal = true,
                decl = { name = "x", type = false } },
            { _tag = "TopLevel_Var",
                islocal = false,
                decl = { name = "y", type = false } },
        })
    end)

    it("can parse toplevel function declarations", function()
        local program, err = parse_file("./testfiles/toplevel_functions.titan")
        assert.truthy(program)
        assert_ast(program, {
            { _tag = "TopLevel_Func",
                islocal = true,
                name = "fA",
                params = {},
                block = { _tag = "Stat_Block", stats = {} } },

            { _tag = "TopLevel_Func",
                islocal = true,
                name = "fB",
                params = {
                    { _tag = "Decl_Decl", name = "x" },
                },
                block = { _tag = "Stat_Block", stats = {} } },

            { _tag = "TopLevel_Func",
                islocal = true,
                name = "fC",
                params = {
                    { _tag = "Decl_Decl", name = "x" },
                    { _tag = "Decl_Decl", name = "y" },
                },
                block = { _tag = "Stat_Block", stats = {} } },
        })
   end)

    it("can parse types", function()
        local program, err = parse_file("./testfiles/types.titan")
        assert.truthy(program)
        assert_ast(program, {
            { decl = { type = { _tag = "Type_Name", name = "nil" } } },
            { decl = { type = { _tag = "Type_Name", name = "int" } } },
            { decl = { type = { _tag = "Type_Array", subtype =
                                    {_tag = "Type_Name", name = "int" } } } },
            { decl = { type = { _tag = "Type_Array", subtype =
                                { _tag = "Type_Array", subtype =
                                    {_tag = "Type_Name", name = "int" } } } } },
        })
    end)

    it("can parse values", function()
        local program, err = parse_file("./testfiles/values.titan")
        assert.truthy(program)
        assert_ast(program[1].block.stats, {
            { exp = { _tag = "Exp_Nil" }},
            { exp = { _tag = "Exp_Bool", value = false }},
            { exp = { _tag = "Exp_Bool", value = true }},
            { exp = { _tag = "Exp_Integer", value = 10}},
            { exp = { _tag = "Exp_Float", value = 10.0}},
            { exp = { _tag = "Exp_String", value = "asd" }},
            { exp = { _tag = "Exp_Var", var = {
                        _tag = "Var_Name", name = "y" }}},
            { exp = { _tag = "Exp_Integer", value = 1 }},
        })
    end)

    it("can parse table constructors", function()
        local program, error = parse_file("./testfiles/tablecons.titan")
        assert.truthy(program)
        assert_ast(program[1].block.stats, {
            { exp = { _tag = "Exp_Table", exps = {} }},
            { exp = { _tag = "Exp_Table", exps = {
                { value = 10 },
                { value = 20 },
                { value = 30 }, }}},
            { exp = { _tag = "Exp_Table", exps = {
                { value = 40 },
                { value = 50 },
                { value = 60 }, }}},
        })
    end)

    it("can parse statements", function()
        local program, err = parse_file("./testfiles/statements.titan")
        assert.truthy(program)
        assert_ast(program[1].block.stats, {
            { _tag = "Stat_While",
              condition = { _tag = "Exp_Bool" },
              block = { _tag = "Stat_Block" } },

            { _tag = "Stat_Repeat",
              block = { _tag = "Stat_Block" },
              condition = { _tag = "Exp_Bool" }, },

            { _tag = "Stat_If",
                thens = {
                    { _tag = "Then_Then", condition = { value = 10 } },
                },
              elsestat = false, },

            { _tag = "Stat_If",
                thens = {
                    { _tag = "Then_Then", condition = { value = 20 } },
                },
                elsestat = { _tag = "Stat_Block" }, },


            { _tag = "Stat_If",
                thens = {
                    { _tag = "Then_Then", condition = { value = 30 } },
                    { _tag = "Then_Then", condition = { value = 40 } },
                },
                elsestat = false, },

            { _tag = "Stat_If",
              thens = {
                    { _tag = "Then_Then", condition = { value = 50 } },
                    { _tag = "Then_Then", condition = { value = 60 } },
                },
                elsestat = { _tag = "Stat_Block" }, },

            { _tag = "Stat_Block",
                stats = {
                    { _tag = "Stat_Decl",
                        decl = { name = "x" },
                        exp = { value = 10 } },
                    { _tag = "Stat_Assign",
                        var = { name = "x" },
                        exp = { value = 11 } },
                    { _tag = "Stat_Call",
                        callexp = { _tag = "Exp_Call" } } } },

            { _tag = "Stat_For",
              block = {
                stats = {
                  { _tag = "Stat_Assign",
                    exp = { var = { _tag = "Var_Name", name = "i" } },
                    var = { _tag = "Var_Name", name = "i" } } } },
              decl = { _tag = "Decl_Decl", name = "i", type = false },
              finish = { _tag = "Exp_Integer", value = 2 },
              inc =    { _tag = "Exp_Integer", value = 3 },
              start =  { _tag = "Exp_Integer", value = 1 } },

            { _tag = "Stat_Return", exp = { _tag = "Exp_Var" } },
        })
    end)

    it("can parse return statements", function()
        -- Just check if it succeeds or fails in all the cases.

        local program, err = parse_file("./testfiles/return_statements.titan")
        assert.truthy(program)
    end)

    it("return statements must be the last in the block", function()
        local program, err =
            parse_file("./testfiles/return_statement_not_last.titan")
        assert.falsy(program)
        assert.are.same("EndFunc", err.label)
    end)

    it("does not allow extra semicolons after a return", function()
        local program, err =
            parse_file("./testfiles/return_statements_extra_semicolons.titan")
        assert.falsy(program)
        assert.are.same("EndFunc", err.label)
    end)

    it("Expected a function name after 'function'.", function()
        local program, err =
            parse_file("./testfiles/parser/nameFunc.titan")
        assert.falsy(program)
        assert.are.same("NameFunc", err.label)
    end)

    it("Expected '(' for the parameter list.", function()
        local program, err =
            parse_file("./testfiles/parser/oParPList.titan")
        assert.falsy(program)
        assert.are.same("OParPList", err.label)
    end)
    
		it("Expected ')' to close the parameter list.", function()
        local program, err =
            parse_file("./testfiles/parser/cParPList.titan")
        assert.falsy(program)
        assert.are.same("CParPList", err.label)
    end)
		
    it("Expected ':' after the parameter list.", function()
        local program, err =
            parse_file("./testfiles/parser/colonFunc.titan")
        assert.falsy(program)
        assert.are.same("ColonFunc", err.label)
    end)
		
    it("Expected a type in function declaration.", function()
        local program, err =
            parse_file("./testfiles/parser/typeFunc.titan")
        assert.falsy(program)
        assert.are.same("TypeFunc", err.label)
    end)
		
    it("Expected 'end' to close the function body.", function()
        local program, err =
            parse_file("./testfiles/parser/endFunc.titan")
        assert.falsy(program)
        assert.are.same("EndFunc", err.label)
    end)
		
    it("Expected '=' after variable declaration.", function()
        local program, err =
            parse_file("./testfiles/parser/assignVar.titan")
        assert.falsy(program)
        assert.are.same("AssignVar", err.label)
    end)
		
    it("Expected an expression to initialize variable.", function()
        local program, err =
            parse_file("./testfiles/parser/expVarDec.titan")
        assert.falsy(program)
        assert.are.same("ExpVarDec", err.label)
    end)
	
    it("Expected a record name after 'record'.", function()
        local program, err =
            parse_file("./testfiles/parser/nameRecord.titan")
        assert.falsy(program)
        assert.are.same("NameRecord", err.label)
    end)
    
    it("Expected 'end' to close the record.", function()
        local program, err =
            parse_file("./testfiles/parser/endRecord.titan")
        assert.falsy(program)
        assert.are.same("EndRecord", err.label)
    end)
    
    it("Expected a field in record declaration.", function()
        local program, err =
            parse_file("./testfiles/parser/fieldRecord.titan")
        assert.falsy(program)
        assert.are.same("FieldRecord", err.label)
    end)
    
    it("Expected a name after 'local'.", function()
        local program, err =
            parse_file("./testfiles/parser/nameImport.titan")
        assert.falsy(program)
        assert.are.same("NameImport", err.label)
    end)

    it("Expected the name of a module after '('.", function()
        local program, err =
            parse_file("./testfiles/parser/stringOParImport.titan")
        assert.falsy(program)
        assert.are.same("StringOParImport", err.label)
    end)

    it("Expected ')' to close import declaration.", function()
        local program, err =
            parse_file("./testfiles/parser/cParImport.titan")
        assert.falsy(program)
        assert.are.same("CParImport", err.label)
    end)

    it("Expected the name of a module after 'import'.", function()
        local program, err =
            parse_file("./testfiles/parser/stringImport.titan")
        assert.falsy(program)
        assert.are.same("StringImport", err.label)
    end)
    
    it("Expected a variable name after ','.", function()
        local program, err =
            parse_file("./testfiles/parser/declParList.titan")
        assert.falsy(program)
        assert.are.same("DeclParList", err.label)
    end)
    
    it("Expected a type name after ':'.", function()
        local program, err =
            parse_file("./testfiles/parser/typeDecl.titan")
        assert.falsy(program)
        assert.are.same("TypeDecl", err.label)
    end)

    it("can parse binary and unary operators", function()
        local program, err = parse_file("./testfiles/operators.titan")
        assert.truthy(program)

        assert_ast(program[1].block.stats[1].exp,
            { op = "or",
                lhs = { op = "not", exp = { value = 1 } },
                rhs = { op = "and",
                    lhs = { op = "and",
                        lhs = { value = 2 },
                        rhs = { value = 3 } },
                    rhs = { value = 4} } }
        )

        assert_ast(program[2].block.stats[1].exp,
            { op = "==",
                lhs = { op = "==",
                    lhs = { op = "<=",
                        lhs = { value = 1 },
                        rhs = { value = 2 } },
                    rhs = { op = "<",
                        lhs = { value = 4 },
                        rhs = { value = 5 } } },
                rhs = { op = "~=",
                    lhs = { value = 6 },
                    rhs = { value = 7 } } }
        )

        assert_ast(program[3].block.stats[1].exp,
            { op = "|",
                lhs = { op = "~",
                    lhs = { op = "~", exp = { op = "~", exp = { value = 1 } } },
                    rhs = { op = ">>",
                        lhs = { op = "<<",
                            lhs = { value = 2 },
                            rhs = { value = 3 } } } },
                rhs = { op = "&",
                    lhs = { value = 5 },
                    rhs = { value = 6 } } }
        )

        assert_ast(program[4].block.stats[1].exp,
            { _tag = "Exp_String", value = "abc" }
        )

        assert_ast(program[5].block.stats[1].exp,
            { op = "+",
                lhs = { op = "/",
                    lhs = { op = "-", exp = { op = "-", exp = { value = 1 } } },
                    rhs = { value = 2 } },
                rhs = { op = "*",
                    lhs = { value = 3 },
                    rhs = { op = "#", exp = { value = "a" } } } }
        )

        assert_ast(program[6].block.stats[1].exp,
            { op = "*",
                lhs = { op = "-",
                    exp = { op = "^",
                        lhs = { value = 1 },
                        rhs = { op = "-",
                            exp = { op = "^",
                                lhs = { value = 2 },
                                rhs = { value = 3 } } } } },
                 rhs = { value = 4 } }
        )

        assert_ast(program[7].block.stats[1].exp,
            { _tag = "Exp_Concat", exps = {
                { var = { name = "x" } },
                { var = { name = "y" } },
                { var = { name = "z" } } } }
    )
end)

    it("can parse suffix operators", function()
        local program, err = parse_file("./testfiles/suffix.titan")
        assert.truthy(program)
        assert_ast(program[1].block.stats[1].exp,
            { _tag = "Exp_Unop", op = "-",
                exp = { _tag = "Exp_Binop", op = "^",
                    rhs = { value = 3 },
                    lhs = { _tag = "Exp_Var", var = {
                        _tag = "Var_Bracket",
                        exp2 = { value = 2 },
                        exp1 = { _tag = "Exp_Call",
                            args = { _tag = "Args_Func" },
                            exp = { _tag = "Exp_Call",
                                args = { _tag = "Args_Func" },
                                exp = { _tag = "Exp_Var",
                                    var = { _tag = "Var_Name", name = "x" }}}}}}}}
        )
    end)

    it("only allows call expressions as statements", function()
        local program, err =
            parse_file("./testfiles/non_call_expression_statement.titan")
        assert.falsy(program)
        assert.are.same("EndFunc", err.label)
    end)

    it("can parse calls without parenthesis", function()
        local program, err =
            parse_file("./testfiles/string_and_table_calls.titan")
        assert.truthy(program)
        assert_ast(program[1].block.stats, {
            { callexp = {
                _tag = "Exp_Call", args = {
                    _tag = "Args_Func", args = { } } } },
            { callexp = {
                _tag = "Exp_Call", args = {
                    _tag = "Args_Func", args = {
                        { _tag = "Exp_String", value = "qwe" } } } } },
            { callexp = {
                _tag = "Exp_Call", args = {
                    _tag = "Args_Func", args = {
                        { _tag = "Exp_Table" } } } } },

           --[[ { callexp = {
                _tag = "Exp_Call", args = {
                    _tag = "Args_Method", args = { } } } },
            { callexp = {
                _tag = "Exp_Call", args = {
                    _tag = "Args_Method", args = {
                        { _tag = "Exp_String", value = "asd" } } } } },
            { callexp = {
                _tag = "Exp_Call", args = {
                    _tag = "Args_Method", args = {
                           { _tag = "Exp_Table" } } } } }]]
        })
    end)

    it("can parse import", function ()
        local program, err = parser.parse([[
            local foo = import "module.foo"
        ]])
        assert.truthy(program)
        assert_ast(program, {
            { _tag = "TopLevel_Import", localname = "foo", modname = "module.foo" },
        })
    end)

    it("can parse references to module members", function ()
        local program, err = parser.parse([[
            function f(): nil
                foo.bar = 50
                print(foo.bar)
                foo.write(a, b, c)
            end
        ]])
        assert.truthy(program)
        assert_ast(program[1].block.stats, {
            { var = {
                _tag = "Var_Dot",
                exp = { _tag = "Exp_Var",
                  var = { _tag = "Var_Name", name = "foo" }
                },
                name = "bar" } },
            { callexp = { args = { args = { { var = {
                _tag = "Var_Dot",
                exp = { _tag = "Exp_Var",
                  var = { _tag = "Var_Name", name = "foo" }
                },
              name = "bar" } } } } } },
            { callexp = {
                exp = { var = {
                    _tag = "Var_Dot",
                    exp = { _tag = "Exp_Var",
                      var = { _tag = "Var_Name", name = "foo" }
                    },
                    name = "write" } } } }
        })
    end)

    it("can parse record declarations", function()
        local program, err =
            parse_file("./testfiles/records.titan")
        assert.truthy(program)
        assert_ast(program, {
            { _tag = "TopLevel_Record",
              name = "Point",
              fields = {
                { name = "x", type = { name = "float" } },
                { name = "y", type = { name = "float" } } } },
            { _tag = "TopLevel_Record",
              name = "List",
              fields = {
                { name = "p",
                  type = { subtype = { name = "Point" } } },
                { name = "next", type = { name = "List" } } } },
        })
        assert_ast(program[3].block.stats, {
            { decl = { name = "p1" },
              exp = {
                _tag = "Exp_Call",
                args = { args = { { value = 1.1 }, { value = 2.2 } } },
                exp = { var = {
                  _tag = "Var_Dot",
                  exp = { var = { name = "Point" } },
                  name = "new" } } } },
            { decl = {
                name = "l1",
                type = { name = "List" } },
              exp = {
                _tag = "Exp_Call",
                args = { args = 
                  { { _tag = "Exp_Table" }, { _tag = "Exp_Nil" } } },
                exp = { var = {
                  _tag = "Var_Dot",
                  exp = { var = { name = "List" } },
                  name = "new" } } } },
            { decl = { name = "a" },
              exp = {
                op = "+",
                lhs = {
                  var = {
                    _tag = "Var_Dot",
                    exp = { var = { name = "p1" } },
                    name = "x" } },
                rhs = {
                  var = {
                    _tag = "Var_Dot",
                    exp = { var = { name = "p1" } },
                    name = "y" } } } },
            { decl = { name = "b" },
              exp = {
                var = {
                  _tag = "Var_Dot", 
                  name = "x",
                  exp = { var = {
                    _tag = "Var_Bracket",
                    exp2 = { value = 1 },
                    exp1 = { var = {
                      _tag = "Var_Dot",
                      name = "p",
                      exp = { var = {
                        name = "l1" } } } } } } } } },
            { var = {
                _tag = "Var_Dot",
                exp = { var = { name = "p1" } },
                name = "x" },
              exp = { var = { name = "a" } } }
        })
    end)
end)
