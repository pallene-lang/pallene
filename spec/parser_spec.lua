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
            { decl = { type = { _tag = "Type_Basic", name = "nil" } } },
            { decl = { type = { _tag = "Type_Basic", name = "int" } } },
            { decl = { type = { _tag = "Type_Array", subtype =
                                    {_tag = "Type_Basic", name = "int" } } } },
            { decl = { type = { _tag = "Type_Array", subtype =
                                { _tag = "Type_Array", subtype =
                                    {_tag = "Type_Basic", name = "int" } } } } },
        })
    end)

    it("can parse values", function()
        local program, err = parse_file("./testfiles/values.titan")
        assert.truthy(program)
        assert_ast(program[1].block.stats, {
            { exp = { _tag = "Exp_Value", value = nil }},
            { exp = { _tag = "Exp_Value", value = false }},
            { exp = { _tag = "Exp_Value", value = true }},
            { exp = { _tag = "Exp_Value", value = 10}},
            { exp = { _tag = "Exp_Value", value = "asd" }},
            { exp = { _tag = "Exp_Var", var = {
                        _tag = "Var_Name", name = "y" }}},
            { exp = { _tag = "Exp_Value", value = 1 }},
        })
    end)

    it("can parse table constructors", function()
        local program, error = parse_file("./testfiles/tablecons.titan")
        assert.truthy(program)
        assert_ast(program[1].block.stats, {
            { exp = { _tag = "Exp_Table", exps = {} }},
            { exp = { _tag = "Exp_Table", exps = {
                { _tag = "Exp_Value", value = 10 },
                { _tag = "Exp_Value", value = 20 },
                { _tag = "Exp_Value", value = 30 }, }}},
            { exp = { _tag = "Exp_Table", exps = {
                { _tag = "Exp_Value", value = 40 },
                { _tag = "Exp_Value", value = 50 },
                { _tag = "Exp_Value", value = 60 }, }}},
        })
    end)

    it("can parse statements", function()
        local program, err = parse_file("./testfiles/statements.titan")
        assert.truthy(program)
        assert_ast(program[1].block.stats, {
            { _tag = "Stat_While",
              condition = { _tag = "Exp_Value" },
              block = { _tag = "Stat_Block" } },
            
            { _tag = "Stat_Repeat",
              block = { _tag = "Stat_Block" },
              condition = { _tag = "Exp_Value" }, },
            
            { _tag = "Stat_If",
                thens = {
                    { _tag = "Then_Then", exp = { value = 10 } },
                },
              elsestat = false, },

            { _tag = "Stat_If",
                thens = {
                    { _tag = "Then_Then", exp = { value = 20 } },
                },
                elsestat = { _tag = "Stat_Block" }, },


            { _tag = "Stat_If",
                thens = {
                    { _tag = "Then_Then", exp = { value = 30 } },
                    { _tag = "Then_Then", exp = { value = 40 } },
                },
                elsestat = false, },

            { _tag = "Stat_If",
              thens = {
                    { _tag = "Then_Then", exp = { value = 50 } },
                    { _tag = "Then_Then", exp = { value = 60 } },
                },
                elsestat = { _tag = "Stat_Block" }, },

            { _tag = "Stat_Block",
                stats = {
                    { _tag = "Stat_Decl", decl = { name = "x" } },
                    { _tag = "Stat_Assign",
                        var = { name = "x" },
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
              finish = { _tag = "Exp_Value", value = 2 },
              inc = { _tag = "Exp_Value", value = 3 },
              start = { _tag = "Exp_Value", value = 1 } },

            { _tag = "Stat_Return", exp = { _tag = "Exp_Var" } },
        })
    end)

    it("can parse return statements", function()
        -- Just check if it succeeds or fails in all the cases.
        
        local program, err = parse_file("./testfiles/return_statements.titan")
        assert.truthy(program)
    end)

    it("return statements must be the last in the block", function()
        pending("implement syntax errors")
    end)

    it("does not allow extra semicolons after a return", function()
        pending("implement syntax errors")
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
            { op = "..",
                lhs = { value = "a" },
                rhs = { op = "..",
                    lhs = { value = "b" },
                    rhs = { value = "c" } } }
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
    end)

    it("can parse suffix operators", function()
        local program, err = parse_file("./testfiles/suffix.titan")
        assert.truthy(program)
        assert_ast(program[1].block.stats[1].exp,
            { _tag = "Exp_Unop", op = "-",
                exp = { _tag = "Exp_Binop", op = "^",
                    rhs = { _tag = "Exp_Value", value = 3 },
                    lhs = { _tag = "Exp_Var", var = {
                        _tag = "Var_Index",
                        exp2 = { _tag = "Exp_Value", value = 2 },
                        exp1 = { _tag = "Exp_Call",
                            args = { _tag = "Args_Method", method = "foo" },
                            exp = { _tag = "Exp_Call",
                                args = { _tag = "Args_Func" },
                                exp = { _tag = "Exp_Var",
                                    var = { _tag = "Var_Name", name = "x" }}}}}}}}
        )
    end)

    it("only allows call expressions as statements", function()
        pending("implement syntax errors")
        -- 10
        -- x[1]
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
                        { _tag = "Exp_Value", value = "qwe" } } } } },
            { callexp = {
                _tag = "Exp_Call", args = {
                    _tag = "Args_Func", args = {
                        { _tag = "Exp_Table" } } } } },

            { callexp = {
                _tag = "Exp_Call", args = {
                    _tag = "Args_Method", args = { } } } },
            { callexp = {
                _tag = "Exp_Call", args = {
                    _tag = "Args_Method", args = {
                        { _tag = "Exp_Value", value = "asd" } } } } },
            { callexp = {
                _tag = "Exp_Call", args = {
                    _tag = "Args_Method", args = {
                        { _tag = "Exp_Table" } } } } },
        })
    end)
end)
