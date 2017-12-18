local parser = require 'titan-compiler.parser'
local util = require 'titan-compiler.util'

--
-- Our syntax trees contain a lot of extra information in them such as token
-- positions, type annotations and so on. To avoid having the tests break all
-- the time when these change, we only check if the subset of the tree that we
-- are interested in is present instead of
--

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

local function assert_is_subset(expected_ast, ast)
    assert.are.same(expected_ast, restrict(expected_ast, ast))
end

--
-- Assertions for full programs
--

local function assert_parses_successfuly(program_str)
    local ast, err = parser.parse(program_str)
    if not ast then
        error(string.format("Unexpected Titan syntax error: %s", err.label))
    end
    return ast
end


local function assert_program_ast(program_str, expected_ast)
    local ast = assert_parses_successfuly(program_str)
    assert_is_subset(expected_ast, ast)
end

local function assert_program_syntax_error(program_str, expected_error_label)
    local ast, err = parser.parse(program_str)
    if ast then
        error(string.format("Expected Titan syntax error %s but parsed successfuly", expected_error_label))
    end
    assert.are.same(expected_error_label, err.label)
end


--
-- Assertions for types
--

local function type_test_program(s)
    return util.render([[
        local x: $TYPE = nil
    ]], { TYPE = s } )
end

local function assert_type_ast(code, expected_ast)
    local program_str = type_test_program(code)
    local program_ast = assert_parses_successfuly(program_str)
    local ast = program_ast[1].decl.type
    assert_is_subset(expected_ast, ast)
end

local function assert_type_syntax_error(code, expected_error_label)
    local program_str = type_test_program(code)
    assert_program_syntax_error(program_str, expected_error_label)
end

--
-- Assertions for expressions
--

local function expression_test_program(s)
    return util.render([[
        function foo(): nil
            x = $EXPR
        end
    ]], { EXPR = s })
end

local function assert_expression_ast(code, expected_ast)
    local program_str = expression_test_program(code)
    local program_ast = assert_parses_successfuly(program_str)
    local ast = program_ast[1].block.stats[1].exp
    assert_is_subset(expected_ast, ast)
end

local function assert_expression_syntax_error(code, expected_error_label)
    local program_str = expression_test_program(code)
    assert_program_syntax_error(program_str, expected_error_label)
end

--
-- Assertions for statements
--

local function statements_test_program(s)
    return util.render([[
        function foo(): nil
            $STATS
        end
    ]], { STATS = s })
end

local function assert_statements_ast(code, expected_ast)
    local program_str = statements_test_program(code)
    local program_ast = assert_parses_successfuly(program_str)
    local ast = program_ast[1].block.stats
    assert_is_subset(expected_ast, ast)
end

local function assert_statements_syntax_error(code, expected_error_label)
    local program_str = statements_test_program(code)
    assert_program_syntax_error(program_str, expected_error_label)
end

--
--
--

describe("Titan parser", function()
    assert:set_parameter("TableFormatLevel", -1)

    it("can parse programs starting with whitespace or comments", function()
        -- (This is easy to get wrong in hand-written LPeg grammars)
        local ast = assert_parses_successfuly("--hello\n--bla\n  ")
        assert.are.same({}, ast)
    end)

    it("can parse toplevel var declarations", function()
        assert_program_ast([[ local x=17 ]], {
            { _tag = "TopLevel_Var",
                islocal = true,
                decl = { name = "x", type = false } }
        })

        assert_program_ast([[ y = 18 ]], {
            { _tag = "TopLevel_Var",
                islocal = false,
                decl = { name = "y", type = false } }
        })
    end)

    it("can parse toplevel function declarations", function()
        assert_program_ast([[
            local function fA(): nil
            end
        ]], {
            { _tag = "TopLevel_Func",
                islocal = true,
                name = "fA",
                params = {},
                block = { _tag = "Stat_Block", stats = {} } },
        })

        assert_program_ast([[
            local function fB(x:int): nil
            end
        ]], {
            { _tag = "TopLevel_Func",
                islocal = true,
                name = "fB",
                params = {
                    { _tag = "Decl_Decl", name = "x" },
                },
                block = { _tag = "Stat_Block", stats = {} } },
        })

        assert_program_ast([[
            local function fC(x:int, y:int): nil
            end
        ]], {
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

    it("allows ommiting the optional return type annotation", function ()
        assert_program_ast([[
            function foo()
            end
            local function bar()
            end
        ]], {
            { _tag = "TopLevel_Func", name = "foo", rettypes = { { name = "nil" } } },
            { _tag = "TopLevel_Func", name = "bar", rettypes = { { name = "nil" } } },
        })
    end)

    it("can parse primitive types", function()
        assert_type_ast("nil", { _tag = "Type_Name", name = "nil" } )
        assert_type_ast("int", { _tag = "Type_Name", name = "int" } )
    end)

    it("can parse array types", function()
        assert_type_ast("{int}",
            { _tag = "Type_Array", subtype =
                {_tag = "Type_Name", name = "int" } } )

        assert_type_ast("{{int}}",
            { _tag = "Type_Array", subtype =
                { _tag = "Type_Array", subtype =
                    {_tag = "Type_Name", name = "int" } } } )
    end)

    describe("can parse function types", function()
        it("with parameter lists of length = 0", function()
            assert_type_ast("() -> ()",
                { _tag = "Type_Function",
                    argtypes = { },
                    rettypes = { } } )
        end)

        it("with parameter lists of length = 1", function()
            assert_type_ast("(a) -> (b)",
                { _tag = "Type_Function",
                    argtypes = { { _tag = "Type_Name", name = "a" } },
                    rettypes = { { _tag = "Type_Name", name = "b" } } } )
        end)

        it("with parameter lists of length >= 2 ", function()
            assert_type_ast("(a,b) -> (c,d,e)",
                { _tag = "Type_Function",
                    argtypes = {
                        { _tag = "Type_Name", name = "a" },
                        { _tag = "Type_Name", name = "b" },
                    },
                    rettypes = {
                        { _tag = "Type_Name", name = "c" },
                        { _tag = "Type_Name", name = "d" },
                        { _tag = "Type_Name", name = "e" },
                    }
                 })
        end)

        it("without the optional parenthesis", function()
            assert_type_ast("a -> b",
                { _tag = "Type_Function",
                    argtypes = { { _tag = "Type_Name", name = "a" } },
                    rettypes = { { _tag = "Type_Name", name = "b" } } } )
        end)


        it("and -> is right associative", function()
            local ast1 = {
                _tag = "Type_Function",
                argtypes = {
                    { _tag = "Type_Name", name = "a" } },
                rettypes = {
                    { _tag = "Type_Function",
                        argtypes = { { _tag = "Type_Name", name = "b" } },
                        rettypes = { { _tag = "Type_Name", name = "c" } } } } }

            local ast2 = {
                _tag = "Type_Function",
                argtypes = {
                    { _tag = "Type_Function",
                        argtypes = { { _tag = "Type_Name", name = "a" } },
                        rettypes = { { _tag = "Type_Name", name = "b" } } } },
                rettypes = {
                    { _tag = "Type_Name", name = "c" } } }

            assert_type_ast("a -> b -> c",   ast1)
            assert_type_ast("a -> (b -> c)", ast1)
            assert_type_ast("(a -> b) -> c", ast2)
        end)

        it("and '->' has higher precedence than ','", function()
            assert_type_ast("(a, b -> c, d) -> e",
                { _tag = "Type_Function",
                    argtypes = {
                        { _tag = "Type_Name", name = "a" },
                        { _tag = "Type_Function",
                          argtypes = { { _tag = "Type_Name", name = "b" } },
                          rettypes = { { _tag = "Type_Name", name = "c" } } },
                        { _tag = "Type_Name", name = "d" } },
                    rettypes = { { _tag = "Type_Name", name = "e" } } } )
        end)
    end)

    it("can parse values", function()
        assert_expression_ast("nil",   { _tag = "Exp_Nil" })
        assert_expression_ast("false", { _tag = "Exp_Bool", value = false })
        assert_expression_ast("true",  { _tag = "Exp_Bool", value = true })
        assert_expression_ast("10",    { _tag = "Exp_Integer", value = 10})
        assert_expression_ast("10.0",  { _tag = "Exp_Float", value = 10.0})
        assert_expression_ast("'asd'", { _tag = "Exp_String", value = "asd" })
    end)

    it("can parse variables", function()
        assert_expression_ast("y", { _tag = "Exp_Var", var = { _tag = "Var_Name", name = "y" }})
    end)

    it("can parse parenthesized expressions", function()
        assert_expression_ast("((1))", { _tag = "Exp_Integer", value = 1 })
    end)

    it("can parse table constructors", function()
        assert_expression_ast("{}",
            { _tag = "Exp_InitList", fields = {} })

        assert_expression_ast("{10,20,30}",
            { _tag = "Exp_InitList", fields = {
                { exp = { value = 10 } },
                { exp = { value = 20 } },
                { exp = { value = 30 } }, }})

        assert_expression_ast("{40;50;60;}", -- (semicolons)
            { _tag = "Exp_InitList", fields = {
                { exp = { value = 40 } },
                { exp = { value = 50 } },
                { exp = { value = 60 } }, }})
    end)

    describe("can parse while statements", function()
        assert_statements_ast("while true do end", {
            { _tag = "Stat_While",
              condition = { _tag = "Exp_Bool" },
              block = { _tag = "Stat_Block" } }
        })
    end)

    describe("can parse repeat-until statements", function()
        assert_statements_ast("repeat until false", {
            { _tag = "Stat_Repeat",
              block = { _tag = "Stat_Block" },
              condition = { _tag = "Exp_Bool" }, }
        })
    end)

    describe("can parse if statements", function()
        assert_statements_ast("if 10 then end", {
            { _tag = "Stat_If",
                thens = {
                    { _tag = "Then_Then", condition = { value = 10 } },
                },
              elsestat = false }
        })

        assert_statements_ast("if 20 then else end", {
            { _tag = "Stat_If",
                thens = {
                    { _tag = "Then_Then", condition = { value = 20 } },
                },
                elsestat = { _tag = "Stat_Block" } }
        })

        assert_statements_ast("if 30 then elseif 40 then end", {
            { _tag = "Stat_If",
                thens = {
                    { _tag = "Then_Then", condition = { value = 30 } },
                    { _tag = "Then_Then", condition = { value = 40 } },
                },
                elsestat = false }
        })

        assert_statements_ast("if 50 then elseif 60 then else end", {
            { _tag = "Stat_If",
              thens = {
                    { _tag = "Then_Then", condition = { value = 50 } },
                    { _tag = "Then_Then", condition = { value = 60 } },
                },
                elsestat = { _tag = "Stat_Block" } }
        })
    end)

    it("can parse do-while blocks", function()
        assert_statements_ast([[
            do
                local x = 10; x = 11
                print("Hello", "World")
            end
        ]], {
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
        })
    end)

    it("can parse numeric for loops", function()
        assert_statements_ast([[
            for i = 1, 2, 3 do
                x = i
            end
        ]], {
            { _tag = "Stat_For",
              block = {
                stats = {
                  { _tag = "Stat_Assign",
                    exp = { var = { _tag = "Var_Name", name = "i" } },
                    var = { _tag = "Var_Name", name = "x" } } } },
              decl = { _tag = "Decl_Decl", name = "i", type = false },
              finish = { _tag = "Exp_Integer", value = 2 },
              inc =    { _tag = "Exp_Integer", value = 3 },
              start =  { _tag = "Exp_Integer", value = 1 } },
        })
    end)

    it("can parse return statements", function()
        assert_statements_ast("return", {
            { _tag = "Stat_Return", exp = false }})

        assert_statements_ast("return;", {
            { _tag = "Stat_Return", exp = false }})

        assert_statements_ast("return x", {
            { _tag = "Stat_Return", exp = { _tag = "Exp_Var" } },
        })
        assert_statements_ast("return x;", {
            { _tag = "Stat_Return", exp = { _tag = "Exp_Var" } },
        })
    end)

    it("requires that return statements be the last in the block", function()
        assert_statements_syntax_error([[
            return 10
            return 11
        ]], "EndFunc")
    end)

    it("does not allow extra semicolons after a return", function()
        assert_statements_syntax_error([[
            return;;
        ]], "EndFunc")
    end)

    it("can parse binary and unary operators", function()
        assert_expression_ast([[not 1 or 2 and 3 and 4]],
            { op = "or",
                lhs = { op = "not", exp = { value = 1 } },
                rhs = { op = "and",
                    lhs = { op = "and",
                        lhs = { value = 2 },
                        rhs = { value = 3 } },
                    rhs = { value = 4} } })

        assert_expression_ast([[(1 <= 2) == (4 < 5) == (6 ~= 7)]],
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
                    rhs = { value = 7 } } })

        assert_expression_ast([[~~1 ~ 2 << 3 >> 4 | 5 & 6]],
            { op = "|",
                lhs = { op = "~",
                    lhs = { op = "~", exp = { op = "~", exp = { value = 1 } } },
                    rhs = { op = ">>",
                        lhs = { op = "<<",
                            lhs = { value = 2 },
                            rhs = { value = 3 } } } },
                rhs = { op = "&",
                    lhs = { value = 5 },
                    rhs = { value = 6 } } })

        assert_expression_ast([[- -1 / 2 + 3 * # "a"]],
            { op = "+",
                lhs = { op = "/",
                    lhs = { op = "-", exp = { op = "-", exp = { value = 1 } } },
                    rhs = { value = 2 } },
                rhs = { op = "*",
                    lhs = { value = 3 },
                    rhs = { op = "#", exp = { value = "a" } } } })

        -- concatenation is right associative
        -- and has less precedence than prefix operators
        assert_expression_ast([[-x .. -y .. -z]],
            { _tag = "Exp_Concat", exps = {
                { op = "-", exp = { var = { name = "x" } } },
                { op = "-", exp = { var = { name = "y" } } },
                { op = "-", exp = { var = { name = "z" } } },
            } })

        -- exponentiation is also right associative
        -- but it has a higher precedence than prefix operators
        assert_expression_ast([[-1 ^ -2 ^ 3 * 4]],
            { op = "*",
                lhs = { op = "-",
                    exp = { op = "^",
                        lhs = { value = 1 },
                        rhs = { op = "-",
                            exp = { op = "^",
                                lhs = { value = 2 },
                                rhs = { value = 3 } } } } },
                 rhs = { value = 4 } })
    end)

    it("constant folds concatenation expressions", function()
        assert_expression_ast([["a" .. "b" .. "c"]],
            { _tag = "Exp_String", value = "abc" })

        assert_expression_ast([[1 .. 2]],
            { _tag = "Exp_String", value = "12" })

        assert_expression_ast([[2.5 .. 1.5]],
            { _tag = "Exp_String", value = "2.51.5" })

        assert_expression_ast([["a" .. 2]],
            { _tag = "Exp_String", value = "a2" })

        assert_expression_ast([[2 .. "a"]],
            { _tag = "Exp_String", value = "2a" })
    end)

    it("can parse suffix operators", function()
        assert_expression_ast([[ - x()()[2] ^ 3]],
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
                                    var = { _tag = "Var_Name", name = "x" }}}}}}}})
    end)

    it("can parse function calls without the optional parenthesis", function()
        assert_expression_ast([[ f() ]],
            { _tag = "Exp_Call", args = {
                _tag = "Args_Func", args = { } } })

        assert_expression_ast([[ f "qwe" ]],
            { _tag = "Exp_Call", args = {
                _tag = "Args_Func", args = {
                    { _tag = "Exp_String", value = "qwe" } } } })

        assert_expression_ast([[ f {} ]],
            { _tag = "Exp_Call", args = {
                _tag = "Args_Func", args = {
                    { _tag = "Exp_InitList" } } } })
    end)

    it("can parse method calls without the optional parenthesis", function()
        assert_expression_ast([[ o:m () ]],
            { _tag = "Exp_Call", args = {
                _tag = "Args_Method", args = { } } })

        assert_expression_ast([[ o:m "asd" ]],
            { _tag = "Exp_Call", args = {
                _tag = "Args_Method", args = {
                    { _tag = "Exp_String", value = "asd" } } } })

        assert_expression_ast([[ o:m {} ]],
            { _tag = "Exp_Call", args = {
                _tag = "Args_Method", args = {
                    { _tag = "Exp_InitList" } } } })
    end)

    it("only allows call expressions as statements", function()
        -- Currently the error messages mention something else

        assert_statements_syntax_error([[
            (f)
        ]], "ExpStat")

        assert_statements_syntax_error([[
            1 + 1
        ]], "ExpStat")
    end)

    it("can parse import", function ()
        assert_program_ast([[ local foo = import "module.foo" ]], {
            { _tag = "TopLevel_Import", localname = "foo", modname = "module.foo" },
        })
    end)

    it("can parse references to module members", function ()
        assert_statements_ast([[
            foo.bar = 50
            print(foo.bar)
            foo.write(a, b, c)
        ]], {
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
        assert_program_ast([[
            record Point
                x: float
                y: float
            end
        ]], {
            { _tag = "TopLevel_Record",
              name = "Point",
              fields = {
                { name = "x", type = { name = "float" } },
                { name = "y", type = { name = "float" } } } },
        })

        assert_program_ast([[
            record List
                p: {Point};
                next: List;
            end
        ]], {
            { _tag = "TopLevel_Record",
              name = "List",
              fields = {
                { name = "p",
                  type = { subtype = { name = "Point" } } },
                { name = "next", type = { name = "List" } } } },
        })
    end)

    it("can parse record constructors", function()
        assert_expression_ast([[ { x = 1.1, y = 2.2 } ]],
            { _tag = "Exp_InitList", fields = {
                { name = "x", exp = { value = 1.1 } },
                { name = "y", exp = { value = 2.2 } } }})

        assert_expression_ast([[ { p = {}, next = nil } ]],
            { _tag = "Exp_InitList", fields = {
                { name = "p",    exp = { _tag = "Exp_InitList" } },
                { name = "next", exp = { _tag = "Exp_Nil" } } }})

        assert_expression_ast([[ Point.new(1.1, 2.2) ]],
            { _tag = "Exp_Call",
                args = { args = {
                  { value = 1.1 },
                  { value = 2.2 } } },
                exp = { var = {
                    _tag = "Var_Dot",
                    exp = { var = { name = "Point" } },
                    name = "new" } } })

        assert_expression_ast([[ List.new({}, nil) ]],
            { _tag = "Exp_Call",
                args = { args = {
                  { _tag = "Exp_InitList" },
                  { _tag = "Exp_Nil" } } },
                exp = { var = {
                    _tag = "Var_Dot",
                    exp = { var = { name = "List" } },
                    name = "new" } } })
    end)

    it("can parse record field access", function()
        assert_expression_ast([[ p.x ]],
            { _tag = "Exp_Var", var = { _tag = "Var_Dot",
                name = "x",
                exp = { _tag = "Exp_Var", var = { _tag = "Var_Name",
                    name = "p" } } } })

        assert_expression_ast([[ a.b[1].c ]],
            { _tag = "Exp_Var", var = { _tag = "Var_Dot",
                name = "c",
                exp = { _tag = "Exp_Var", var = { _tag = "Var_Bracket",
                    exp2 = { value = 1 },
                    exp1 = { _tag = "Exp_Var", var = { _tag = "Var_Dot",
                        name = "b",
                        exp = { _tag = "Exp_Var", var = { _tag = "Var_Name",
                            name = "a" } } } } } } } })
    end)

    it("can parse cast expressions", function()
        assert_expression_ast([[ foo as integer ]],
            { _tag = "Exp_Cast", exp = { _tag = "Exp_Var" }, target = { _tag = "Type_Name", name = "integer" } })
        assert_expression_ast([[ a.b[1].c as integer ]],
            { _tag = "Exp_Cast", exp = { _tag = "Exp_Var" }, target = { _tag = "Type_Name", name = "integer" } })
        assert_expression_ast([[ foo as { integer } ]],
            { _tag = "Exp_Cast", exp = { _tag = "Exp_Var" }, target = { _tag = "Type_Array" } })
        assert_expression_ast([[ 2 + foo as integer ]],
            { rhs = { _tag = "Exp_Cast", exp = { _tag = "Exp_Var" }, target = { _tag = "Type_Name", name = "integer" } }})
    end)

    it("does not allow parentheses in the LHS of an assignment", function()
        assert_statements_syntax_error([[ local (x) = 42 ]], "DeclLocal")
        assert_statements_syntax_error([[ (x) = 42 ]], "ExpAssign")
    end)

    it("uses specific error labels for some errors", function()

        assert_program_syntax_error([[
            function () : int
            end
        ]], "NameFunc")

        assert_program_syntax_error([[
            function foo : int
            end
        ]], "LParPList")

        assert_program_syntax_error([[
            function foo ( : int
            end
        ]], "RParPList")

        assert_program_syntax_error([[
            function foo () :
                local x = 3
            end
        ]], "TypeFunc")

        assert_program_syntax_error([[
            function foo () : int
              local x = 3
              return x
        ]], "EndFunc")

        assert_program_syntax_error([[
            x 3
        ]], "AssignVar")

        assert_program_syntax_error([[
            x =
        ]], "ExpVarDec")

        assert_program_syntax_error([[
            record
        ]], "NameRecord")

        assert_program_syntax_error([[
            record A
                x : int
        ]], "EndRecord")

        assert_program_syntax_error([[
            record A
            end
        ]], "FieldRecord")

        assert_program_syntax_error([[
            local = import "bola"
        ]], "NameImport")

        assert_program_syntax_error([[
            local bola = import ()
        ]], "StringLParImport")

        assert_program_syntax_error([[
            local bola = import ('bola'
        ]], "RParImport")

        assert_program_syntax_error([[
            local bola = import
        ]], "StringImport")

        assert_program_syntax_error([[
            function foo (a:int, ) : int
            end
        ]], "DeclParList")

        assert_program_syntax_error([[
            function foo (a: ) : int
            end
        ]], "TypeDecl")


        assert_type_syntax_error([[ {} ]], "TypeType")

        assert_type_syntax_error([[ {int ]], "RCurlyType")

        assert_type_syntax_error([[ (a,,,) -> b ]], "TypelistType")

        assert_type_syntax_error([[ (a, b -> b  ]], "RParenTypelist")

        assert_type_syntax_error([[ (a, b) -> = nil ]], "TypeReturnTypes")


        assert_program_syntax_error([[
            record A
                x  int
            end
        ]], "ColonRecordField")

        assert_program_syntax_error([[
            record A
                x : function
            end
        ]], "TypeRecordField")

        assert_program_syntax_error([[
            function f ( x : int) : string
                do
                return "42"
        ]], "EndBlock")

        assert_statements_syntax_error([[
            while do
                x = x - 1
            end
        ]], "ExpWhile")

        assert_statements_syntax_error([[
            while x > 3
                x = x - 1
            end
        ]], "DoWhile")

        assert_statements_syntax_error([[
            while x > 3 do
                x = x - 1
                return 42
            return 41
        ]], "EndWhile")

        assert_statements_syntax_error([[
            repeat
                x = x - 1
            end
        ]], "UntilRepeat")

        assert_statements_syntax_error([[
            repeat
                x = x - 1
            until
        ]], "ExpRepeat")

        assert_statements_syntax_error([[
            if then
                x = x - 1
            end
        ]], "ExpIf")

        assert_statements_syntax_error([[
            if x > 10
                x = x - 1
            end
        ]], "ThenIf")

        assert_statements_syntax_error([[
            if x > 10 then
                x = x - 1
                return 42
            return 41
        ]], "EndIf")

        assert_statements_syntax_error([[
            for = 1, 10 do
            end
        ]], "DeclFor")

        assert_statements_syntax_error([[
            for x  1, 10 do
            end
        ]], "AssignFor")

        assert_statements_syntax_error([[
            for x = , 10 do
            end
        ]], "Exp1For")

        assert_statements_syntax_error([[
            for x = 1 10 do
            end
        ]], "CommaFor")

        assert_statements_syntax_error([[
            for x = 1, do
            end
        ]], "Exp2For")

        assert_statements_syntax_error([[
            for x = 1, 10, do
            end
        ]], "Exp3For")

        assert_statements_syntax_error([[
            for x = 1, 10, 1
            end
        ]], "DoFor")

        assert_statements_syntax_error([[
            for x = 1, 10, 1 do
                return 42
            return 41
        ]], "EndFor")

        assert_statements_syntax_error([[
            local = 3
        ]], "DeclLocal")

        assert_statements_syntax_error([[
            local x  3
        ]], "AssignLocal")

        assert_statements_syntax_error([[
            local x =
        ]], "ExpLocal")

        assert_statements_syntax_error([[
            x
        ]], "AssignAssign")

        assert_statements_syntax_error([[
            x =
        ]], "ExpAssign")

        assert_statements_syntax_error([[
            if x > 1 then
                x = x - 1
            elseif then
            end
        ]], "ExpElseIf")

        assert_statements_syntax_error([[
            if x > 1 then
                x = x - 1
            elseif x > 0
            end
        ]], "ThenElseIf")

        assert_expression_syntax_error([[ 1 + ]], "OpExp")

        assert_expression_syntax_error([[ obj:() ]], "NameColonExpSuf")

        assert_expression_syntax_error([[ obj:f + 1 ]], "FuncArgsExpSuf")

        assert_expression_syntax_error([[ y[] ]], "ExpExpSuf")

        assert_expression_syntax_error([[ y[1 ]], "RBracketExpSuf")

        assert_expression_syntax_error([[ y.() ]], "NameDotExpSuf")

        assert_expression_syntax_error([[ () ]], "ExpSimpleExp")

        assert_expression_syntax_error([[ (42 ]], "RParSimpleExp")

        assert_expression_syntax_error([[ f(42 ]], "RParFuncArgs")

        assert_expression_syntax_error([[ f(42,) ]], "ExpExpList")

        assert_expression_syntax_error([[ y{42 ]], "RCurlyInitList")

        assert_expression_syntax_error([[ y{42,,} ]], "ExpFieldList")

        assert_expression_syntax_error([[ foo as ]], "CastMissingType")
    end)
end)
