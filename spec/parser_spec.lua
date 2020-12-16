local driver = require 'pallene.driver'
local util = require 'pallene.util'

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

local function assert_is_subset(expected_ast, parsed_ast)
    assert.are.same(expected_ast, restrict(expected_ast, parsed_ast))
end

--
-- Assertions for full programs
--

local function parse(code)
    return driver.compile_internal("__test__.pln", code, "ast")
end

local function assert_parses_successfuly(program_str)
    local prog_ast, errors = parse(program_str)
    if not prog_ast then
        error(string.format("Unexpected Pallene syntax error: %s", errors[1]))
    end
    return prog_ast
end

local function assert_program_ast(program_str, expected_tls)
    local expected_ast = {
        _tag = "ast.Program.Program",
        tls = expected_tls,
        type_regions = {},
        comment_regions = {}
    }
    local prog_ast = assert_parses_successfuly(program_str)
    assert_is_subset(expected_ast, prog_ast)
end

local function assert_program_syntax_error(program_str, expected_error)
    local prog_ast, errors = parse(program_str)
    if prog_ast then
        error(string.format(
            "Expected Pallene syntax error %s but parsed successfuly",
            expected_error))
    end
    assert.matches(expected_error, errors[1], 1, true)
end

--
-- Assertions for types
--

local function type_test_program(s)
    return (util.render([[
        local x: ${TYPE} = nil
    ]], { TYPE = s } ))
end

local function assert_type_ast(code, expected_ast)
    local program_str = type_test_program(code)
    local program_ast = assert_parses_successfuly(program_str)
    local type_ast = program_ast.tls[1].decls[1].type
    assert_is_subset(expected_ast, type_ast)
end

local function assert_type_syntax_error(code, expected_error)
    local program_str = type_test_program(code)
    assert_program_syntax_error(program_str, expected_error)
end

--
-- Assertions for expressions
--

local function expression_test_program(s)
    return (util.render([[
        export function foo()
            x = ${EXPR}
        end
    ]], { EXPR = s }))
end

local function assert_expression_ast(code, expected_ast)
    local program_str = expression_test_program(code)
    local program_ast = assert_parses_successfuly(program_str)
    local exp_ast = program_ast.tls[1].value.body.stats[1].exps[1]
    assert_is_subset(expected_ast, exp_ast)
end

local function assert_expression_syntax_error(code, expected_error)
    local program_str = expression_test_program(code)
    assert_program_syntax_error(program_str, expected_error)
end

--
-- Assertions for statements
--

local function statements_test_program(s)
    return (util.render([[
        export function foo()
            ${STATS}
        end
    ]], { STATS = s }))
end

local function assert_statements_ast(code, expected_ast)
    local program_str = statements_test_program(code)
    local program_ast = assert_parses_successfuly(program_str)
    local stats_ast = program_ast.tls[1].value.body.stats
    assert_is_subset(expected_ast, stats_ast)
end

local function assert_statements_syntax_error(code, expected_error)
    local program_str = statements_test_program(code)
    assert_program_syntax_error(program_str, expected_error)
end

--
--
--

describe("Pallene parser", function()
    local ORIGINAL_FORMAT_LEVEL

    setup(function()
        -- Print the whole AST when it doesn't match, instead of just a handful
        -- of nodes. A depth of 100 should be more than enough. Although the
        -- luassert docs suggest -1 to show an infinite number of levels, that
        -- can get stuck in an infinite loop if we have self-referential tables.
        ORIGINAL_FORMAT_LEVEL = assert:get_parameter("TableFormatLevel")
        assert:set_parameter("TableFormatLevel", 100)
    end)

    teardown(function()
        assert:set_parameter("TableFormatLevel", ORIGINAL_FORMAT_LEVEL)
    end)

    it("can parse programs starting with whitespace or comments", function()
        -- This is easy to get wrong in hand-written LPeg grammars...
        local prog_ast = assert_parses_successfuly("--hello\n--bla\n  ")
        assert.are.same({}, prog_ast.tls)
    end)

    it("can parse toplevel var declarations", function()
        assert_program_ast([[ local x=17 ]], {
            { _tag = "ast.Toplevel.Var",
                decls = { { name = "x", type = false } } }
        })
    end)

    it("does not allow global variables", function()
        assert_program_syntax_error([[ x=17 ]],
            "Toplevel variable declarations must have a 'local' or 'export' modifier")
    end)

    it("cannot define function without export or local modifier", function()
        assert_program_syntax_error([[
            function f() : integer
                return 5319
            end
        ]],
        "Toplevel function declarations must have a 'local' or 'export' modifier")
    end)

    it("last function without export or local modifier", function()
        assert_program_syntax_error([[
            export function a()
            end

            function f() : integer
                return 5319
            end
        ]],
        "Toplevel function declarations must have a 'local' or 'export' modifier")
    end)

    it("first function without export or local modifier", function()
        assert_program_syntax_error([[
            function a()
            end

            export function f() : integer
                return 5319
            end
        ]],
        "Toplevel function declarations must have a 'local' or 'export' modifier")
    end)

    it("toplevel variable declaration without export or local modifier", function()
        assert_program_syntax_error([[
            a,m="s","r"
        ]],
        "Toplevel variable declarations must have a 'local' or 'export' modifier")
    end)

    it("toplevel variable declaration without export or local modifier (without comma)", function()
        assert_program_syntax_error([[
            a="s"
        ]],
        "Toplevel variable declarations must have a 'local' or 'export' modifier")
    end)

    it("can parse toplevel function declarations", function()
        assert_program_ast([[
            local function fA() : float
            end
        ]], {
            { _tag = "ast.Toplevel.Func",
                visibility = "local",
                decl = {
                    name = "fA",
                    type = {
                        arg_types = {},
                        ret_types = {
                            { _tag = "ast.Type.Name", name = "float" }, }, } },
                value = {
                    _tag = "ast.Exp.Lambda",
                    arg_decls  = {},
                    body = {
                        _tag = "ast.Stat.Block",
                        stats = {} } } },
        })

        assert_program_ast([[
            local function fB(x:integer) : float
            end
        ]], {
            { _tag = "ast.Toplevel.Func",
                visibility = "local",
                decl = {
                    name = "fB",
                    type = {
                        arg_types = {
                            { _tag = "ast.Type.Name", name = "integer" }, },
                        ret_types = {
                            { _tag = "ast.Type.Name", name = "float" }, }, } },
                value = {
                    _tag = "ast.Exp.Lambda",
                    arg_decls = { { name = "x" } },
                    body = {
                        _tag = "ast.Stat.Block",
                        stats = {} } } },
        })

        assert_program_ast([[
            local function fC(x:integer, y:integer) : float
            end
        ]], {
            { _tag = "ast.Toplevel.Func",
                visibility = "local",
                decl = {
                    name = "fC",
                    type = {
                        arg_types = {
                            { _tag = "ast.Type.Name", name = "integer" },
                            { _tag = "ast.Type.Name", name = "integer" }, },
                        ret_types = {
                            { _tag = "ast.Type.Name", name = "float" }, }, } },
                value = {
                    _tag = "ast.Exp.Lambda",
                    arg_decls = { { name = "x" }, { name = "y" } },
                    body = {
                        _tag = "ast.Stat.Block",
                        stats = {} } } },
        })
    end)

    it("allows ommiting the optional return type annotation", function ()
        assert_program_ast([[
            export function foo()
            end
            local function bar()
            end
        ]], {
            { _tag = "ast.Toplevel.Func",
                visibility = "export",
                decl = {
                    name = "foo",
                    type = { arg_types = {}, ret_types = {} } }, },
            { _tag = "ast.Toplevel.Func",
                visibility = "local",
                decl = {
                    name = "bar",
                    type = { arg_types = {}, ret_types = {} } }, },
        })
    end)

    it("can parse multiple return expressions", function()
        assert_statements_ast("return 1, 2, 3", {
            { _tag = "ast.Stat.Return",
              exps = { { _tag = "ast.Exp.Integer", value = 1 },
                       { _tag = "ast.Exp.Integer", value = 2 },
                       { _tag = "ast.Exp.Integer", value = 3 } } }
        })
    end)

    it("can parse multiple declarations", function()
        assert_statements_ast("local a, b = 1, 2", {
            { _tag  = "ast.Stat.Decl",
              decls = { { _tag = "ast.Decl.Decl", name = "a" },
                        { _tag = "ast.Decl.Decl", name = "b" } },
              exps  = { { _tag = "ast.Exp.Integer", value = 1 },
                        { _tag = "ast.Exp.Integer", value = 2 } } }
        })
    end)

    it("can parse multiple assignments", function()
        assert_statements_ast("a, b = 1, 2", {
            { _tag = "ast.Stat.Assign",
              exps = { { _tag = "ast.Exp.Integer", value = 1 },
                        { _tag = "ast.Exp.Integer", value = 2 } },
              vars = { { _tag = "ast.Var.Name", name = "a" },
                       { _tag = "ast.Var.Name", name = "b" } } }
        })
    end)

    it("can parse primitive types", function()
        assert_type_ast("nil", { _tag = "ast.Type.Nil" } )
        assert_type_ast("int", { _tag = "ast.Type.Name", name = "int" } )
    end)

    it("can parse array types", function()
        assert_type_ast("{int}",
            { _tag = "ast.Type.Array", subtype =
                {_tag = "ast.Type.Name", name = "int" } } )

        assert_type_ast("{{int}}",
            { _tag = "ast.Type.Array", subtype =
                { _tag = "ast.Type.Array", subtype =
                    {_tag = "ast.Type.Name", name = "int" } } } )
    end)

    it("can parse table types", function()
        assert_type_ast("{}",
            { _tag = "ast.Type.Table",
                fields = {} })

        assert_type_ast("{ x: float }",
            { _tag = "ast.Type.Table",
              fields = {
                { name = "x", type = { _tag = "ast.Type.Name", name = "float" } } } })

        assert_type_ast("{ x: float, y: integer }",
            { _tag = "ast.Type.Table",
              fields = {
                { name = "x", type = { _tag = "ast.Type.Name", name = "float" } },
                { name = "y", type = { _tag = "ast.Type.Name", name = "integer" } } } })

        assert_type_ast("{ a: {integer} }",
            { _tag = "ast.Type.Table",
              fields = {
                { name = "a", type = { _tag = "ast.Type.Array" } } } })
    end)

    describe("can parse function types", function()
        it("with parameter lists of length = 0", function()
            assert_type_ast("() -> ()",
                { _tag = "ast.Type.Function",
                    arg_types = { },
                    ret_types = { } } )
        end)

        it("with parameter lists of length = 1", function()
            assert_type_ast("(a) -> (b)",
                { _tag = "ast.Type.Function",
                    arg_types = { { _tag = "ast.Type.Name", name = "a" } },
                    ret_types = { { _tag = "ast.Type.Name", name = "b" } } } )
        end)

        it("with parameter lists of length >= 2 ", function()
            assert_type_ast("(a,b) -> (c,d,e)",
                { _tag = "ast.Type.Function",
                    arg_types = {
                        { _tag = "ast.Type.Name", name = "a" },
                        { _tag = "ast.Type.Name", name = "b" },
                    },
                    ret_types = {
                        { _tag = "ast.Type.Name", name = "c" },
                        { _tag = "ast.Type.Name", name = "d" },
                        { _tag = "ast.Type.Name", name = "e" },
                    }
                 })
        end)

        it("without the optional parenthesis", function()
            assert_type_ast("a -> b",
                { _tag = "ast.Type.Function",
                    arg_types = { { _tag = "ast.Type.Name", name = "a" } },
                    ret_types = { { _tag = "ast.Type.Name", name = "b" } } } )
        end)


        it("and -> is right associative", function()
            local ast1 = {
                _tag = "ast.Type.Function",
                arg_types = {
                    { _tag = "ast.Type.Name", name = "a" } },
                ret_types = {
                    { _tag = "ast.Type.Function",
                        arg_types = { { _tag = "ast.Type.Name", name = "b" } },
                        ret_types = { { _tag = "ast.Type.Name", name = "c" } } } } }

            local ast2 = {
                _tag = "ast.Type.Function",
                arg_types = {
                    { _tag = "ast.Type.Function",
                        arg_types = { { _tag = "ast.Type.Name", name = "a" } },
                        ret_types = { { _tag = "ast.Type.Name", name = "b" } } } },
                ret_types = {
                    { _tag = "ast.Type.Name", name = "c" } } }

            assert_type_ast("a -> b -> c",   ast1)
            assert_type_ast("a -> (b -> c)", ast1)
            assert_type_ast("(a -> b) -> c", ast2)
        end)

        it("and '->' has higher precedence than ','", function()
            assert_type_ast("(a, b -> c, d) -> e",
                { _tag = "ast.Type.Function",
                    arg_types = {
                        { _tag = "ast.Type.Name", name = "a" },
                        { _tag = "ast.Type.Function",
                          arg_types = { { _tag = "ast.Type.Name", name = "b" } },
                          ret_types = { { _tag = "ast.Type.Name", name = "c" } } },
                        { _tag = "ast.Type.Name", name = "d" } },
                    ret_types = { { _tag = "ast.Type.Name", name = "e" } } } )
        end)
    end)

    it("can parse type alias", function()
        assert_program_ast([[ typealias point = {float} ]], {
            { _tag = "ast.Toplevel.Typealias",
                name = "point", type = { _tag = "ast.Type.Array" } }
        })
    end)

    it("can parse values", function()
        assert_expression_ast("nil",   { _tag = "ast.Exp.Nil" })
        assert_expression_ast("false", { _tag = "ast.Exp.Bool", value = false })
        assert_expression_ast("true",  { _tag = "ast.Exp.Bool", value = true })
        assert_expression_ast("10",    { _tag = "ast.Exp.Integer", value = 10})
        assert_expression_ast("10.0",  { _tag = "ast.Exp.Float", value = 10.0})
        assert_expression_ast("'asd'", { _tag = "ast.Exp.String", value = "asd" })
    end)

    it("can parse variables", function()
        assert_expression_ast("y", { _tag = "ast.Exp.Var", var = { _tag = "ast.Var.Name", name = "y" }})
    end)

    it("can parse parenthesized expressions", function()
        assert_expression_ast("((1))",
            { _tag = "ast.Exp.Paren",
                exp = { _tag = "ast.Exp.Paren",
                    exp = { _tag = "ast.Exp.Integer", value = 1 }}})
    end)

    it("can parse table constructors", function()
        assert_expression_ast("{}",
            { _tag = "ast.Exp.Initlist", fields = {} })

        assert_expression_ast("{10,20,30}",
            { _tag = "ast.Exp.Initlist", fields = {
                { exp = { value = 10 } },
                { exp = { value = 20 } },
                { exp = { value = 30 } }, }})

        assert_expression_ast("{40;50;60;}", -- (semicolons)
            { _tag = "ast.Exp.Initlist", fields = {
                { exp = { value = 40 } },
                { exp = { value = 50 } },
                { exp = { value = 60 } }, }})
    end)

    describe("can parse while statements", function()
        assert_statements_ast("while true do end", {
            { _tag = "ast.Stat.While",
              condition = { _tag = "ast.Exp.Bool" },
              block = { _tag = "ast.Stat.Block" } }
        })
    end)

    describe("can parse repeat-until statements", function()
        assert_statements_ast("repeat until false", {
            { _tag = "ast.Stat.Repeat",
              block = { _tag = "ast.Stat.Block" },
              condition = { _tag = "ast.Exp.Bool" }, }
        })
    end)

    describe("can parse if statements", function()
        assert_statements_ast("if 10 then end", {
            { _tag = "ast.Stat.If",
                condition = { value = 10 },
                then_ = { _tag = "ast.Stat.Block" },
                else_ = { _tag = "ast.Stat.Block" }, }
        })

        assert_statements_ast("if 20 then else end", {
            { _tag = "ast.Stat.If",
                condition = { value = 20 },
                then_ = { _tag = "ast.Stat.Block" },
                else_ = { _tag = "ast.Stat.Block" }, }
        })

        assert_statements_ast("if 30 then elseif 40 then end", {
            { _tag = "ast.Stat.If",
                condition = { value = 30 },
                then_ = { _tag = "ast.Stat.Block" },
                else_ = { _tag = "ast.Stat.If",
                    condition = { value = 40 }, }, }
        })

        assert_statements_ast("if 50 then elseif 60 then else end", {
            { _tag = "ast.Stat.If",
                condition = { value = 50 },
                then_ = { _tag = "ast.Stat.Block" },
                else_ = { _tag = "ast.Stat.If",
                    condition = { value = 60 }, }, }
        })
    end)

    it("can parse do-while blocks", function()
        assert_statements_ast([[
            do
                local x = 10; x = 11
                print("Hello", "World")
            end
        ]], {
            { _tag = "ast.Stat.Block",
                stats = {
                    { _tag = "ast.Stat.Decl",
                        decls = { { name = "x" } },
                        exps = { { value = 10 } } },
                    { _tag = "ast.Stat.Assign",
                        vars = { { name = "x" } },
                        exps = { { value = 11 } } },
                    { _tag = "ast.Stat.Call",
                        call_exp = { _tag = "ast.Exp.CallFunc" } } } },
        })
    end)

    it("can parse numeric for loops", function()
        assert_statements_ast([[
            for i = 1, 2, 3 do
                x = i
            end
        ]], {
            { _tag = "ast.Stat.ForNum",
              block = {
                stats = {
                  { _tag = "ast.Stat.Assign",
                    exps = { { var = { _tag = "ast.Var.Name", name = "i" } } },
                    vars = { { _tag = "ast.Var.Name", name = "x" } } } } },
              decl = { _tag = "ast.Decl.Decl", name = "i", type = false },
              start =  { _tag = "ast.Exp.Integer", value = 1 },
              limit =  { _tag = "ast.Exp.Integer", value = 2 },
              step =   { _tag = "ast.Exp.Integer", value = 3 }, },
        })
    end)

    it("can parse for-in loops", function()
        assert_statements_ast([[
            for k, v in ipairs(t) do
                x = v
            end
        ]], {
            { _tag = "ast.Stat.ForIn",
              block = {
                stats = {
                  { _tag = "ast.Stat.Assign",
                    exps = { { var = { _tag = "ast.Var.Name", name = "v" } } },
                    vars = { { _tag = "ast.Var.Name", name = "x" } } } } },
              decls = {
                { _tag = "ast.Decl.Decl", name = "k", type = false },
                { _tag = "ast.Decl.Decl", name = "v", type = false }, },
              exps =  {
                { _tag = "ast.Exp.CallFunc", exp  = { _tag = "ast.Exp.Var",
                  var = { _tag = "ast.Var.Name", name = "ipairs" } },
                  args = {
                    { _tag = "ast.Exp.Var" ,
                    var = { name = "t" } } } } }
            }
        })

        assert_statements_ast([[
            for x in foo() do
                x = 1
            end
        ]], {
            { _tag = "ast.Stat.ForIn",
              block = {
                stats = {
                  { _tag = "ast.Stat.Assign",
                   exps = { { value = 1 } },
                   vars = { { _tag = "ast.Var.Name", name = "x" } } } } },
              decls = { { _tag = "ast.Decl.Decl", name = "x", type = false } },
              exps = {
              { _tag = "ast.Exp.CallFunc",
                exp  = { _tag = "ast.Exp.Var",
                var  = { _tag = "ast.Var.Name", name = "foo" } },
                args = { --[[ no args ]] } } }
            }
        })
    end)

    it("can parse return statements", function()
        assert_statements_ast("return", {
            { _tag = "ast.Stat.Return", exps = {} }})

        assert_statements_ast("return;", {
            { _tag = "ast.Stat.Return", exps = {} }})

        assert_statements_ast("return x", {
            { _tag = "ast.Stat.Return", exps = { { _tag = "ast.Exp.Var" } } },
        })
        assert_statements_ast("return x;", {
            { _tag = "ast.Stat.Return", exps = { { _tag = "ast.Exp.Var" } } },
        })
    end)

    it("requires that return statements be the last in the block", function()
        assert_statements_syntax_error([[
            return 10
            return 11
        ]], "Expected 'end' before 'return', to close the 'function' at line 1")
    end)

    it("does not allow extra semicolons after a return", function()
        assert_statements_syntax_error([[
            return;;
        ]], "Expected 'end' before ';', to close the 'function' at line 1")
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
                    lhs = { _tag = "ast.Exp.Paren", exp = { op = "<=",
                        lhs = { value = 1 },
                        rhs = { value = 2 } } },
                    rhs = { _tag = "ast.Exp.Paren", exp = { op = "<",
                        lhs = { value = 4 },
                        rhs = { value = 5 } } } },
                rhs = { _tag = "ast.Exp.Paren", exp = { op = "~=",
                    lhs = { value = 6 },
                    rhs = { value = 7 } } } })

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
            { _tag = "ast.Exp.Binop", op = "..",
                lhs = { op = "-", exp = { var = { name = "x" } } },
                rhs = { _tag = "ast.Exp.Binop", op = "..",
                    lhs = { op = "-", exp = { var = { name = "y" } } },
                    rhs = { op = "-", exp = { var = { name = "z" } } }, } })

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

    it("can parse suffix operators", function()
        assert_expression_ast([[ - x()()[2] ^ 3]],
            { _tag = "ast.Exp.Unop", op = "-",
                exp = { _tag = "ast.Exp.Binop", op = "^",
                    rhs = { value = 3 },
                    lhs = { _tag = "ast.Exp.Var", var = {
                        _tag = "ast.Var.Bracket",
                        k = { value = 2 },
                        t = { _tag = "ast.Exp.CallFunc",
                            args = { },
                            exp = { _tag = "ast.Exp.CallFunc",
                                args = { },
                                exp = { _tag = "ast.Exp.Var",
                                    var = { _tag = "ast.Var.Name", name = "x" }}}}}}}})
    end)

    it("can parse function calls without the optional parenthesis", function()
        assert_expression_ast([[ f() ]],
            { _tag = "ast.Exp.CallFunc", args = { } })

        assert_expression_ast([[ f "qwe" ]],
            { _tag = "ast.Exp.CallFunc", args = {
                { _tag = "ast.Exp.String", value = "qwe" } } })

        assert_expression_ast([[ f {} ]],
            { _tag = "ast.Exp.CallFunc", args = {
                { _tag = "ast.Exp.Initlist" } } })
    end)

    it("can parse method calls without the optional parenthesis", function()
        assert_expression_ast([[ o:m () ]],
            { _tag = "ast.Exp.CallMethod",
                method = "m",
                args = { } })

        assert_expression_ast([[ o:m "asd" ]],
            { _tag = "ast.Exp.CallMethod",
                method = "m",
                args = {
                    { _tag = "ast.Exp.String", value = "asd" } } })

        assert_expression_ast([[ o:m {} ]],
            { _tag = "ast.Exp.CallMethod",
                method = "m",
                args = {
                    { _tag = "ast.Exp.Initlist" } } })
    end)

    it("only allows call expressions as statements", function()
        assert_statements_syntax_error([[
            (f)
        ]], "This expression in a statement position is not a function call")

        assert_statements_syntax_error([[
            1 + 1
        ]], "Unexpected number")
    end)

    it("can parse references to module members", function ()
        assert_statements_ast([[
            foo.bar = 50
            print(foo.bar)
            foo.write(a, b, c)
        ]], {
            { vars = { {
                _tag = "ast.Var.Dot",
                exp = { _tag = "ast.Exp.Var",
                  var = { _tag = "ast.Var.Name", name = "foo" }
              },
                name = "bar" } } },
            { call_exp = { args = { { var = {
                _tag = "ast.Var.Dot",
                exp = { _tag = "ast.Exp.Var",
                  var = { _tag = "ast.Var.Name", name = "foo" }
                },
              name = "bar" } } } } },
            { call_exp = {
                exp = { var = {
                    _tag = "ast.Var.Dot",
                    exp = { _tag = "ast.Exp.Var",
                      var = { _tag = "ast.Var.Name", name = "foo" }
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
            { _tag = "ast.Toplevel.Record",
              name = "Point",
              field_decls = {
                { name = "x", type = { _tag = "ast.Type.Name", name = "float" } },
                { name = "y", type = { _tag = "ast.Type.Name", name = "float" } } } },
        })

        assert_program_ast([[
            record List
                p: {Point}
                next: List
            end
        ]], {
            { _tag = "ast.Toplevel.Record",
              name = "List",
              field_decls = {
                { name = "p",
                  type = { subtype = { name = "Point" } } },
                { name = "next", type = { name = "List" } } } },
        })
    end)

    it("allows empty record declarations", function()
        assert_program_ast([[
            record Empty
            end
        ]], {
            { _tag = "ast.Toplevel.Record",
              name = "Empty",
              field_decls = {}},
        })
    end)

    it("can parse the record field optional separator", function()
        local expected_ast = { {
            field_decls = {
                { name = "x" },
                { name = "y" }
            }
        } }

        assert_program_ast([[
            record Point x: float y: float end
        ]], expected_ast)

        assert_program_ast([[
            record Point x: float; y: float end
        ]], expected_ast)

        assert_program_ast([[
            record Point x: float y: float; end
        ]], expected_ast)

        assert_program_ast([[
            record Point x: float; y: float; end
        ]], expected_ast)
    end)

    it("can parse record constructors", function()
        assert_expression_ast([[ { x = 1.1, y = 2.2 } ]],
            { _tag = "ast.Exp.Initlist", fields = {
                { name = "x", exp = { value = 1.1 } },
                { name = "y", exp = { value = 2.2 } } }})

        assert_expression_ast([[ { p = {}, next = nil } ]],
            { _tag = "ast.Exp.Initlist", fields = {
                { name = "p",    exp = { _tag = "ast.Exp.Initlist" } },
                { name = "next", exp = { _tag = "ast.Exp.Nil" } } }})

        assert_expression_ast([[ Point.new(1.1, 2.2) ]],
            { _tag = "ast.Exp.CallFunc",
                args = {
                  { value = 1.1 },
                  { value = 2.2 } },
                exp = { var = {
                    _tag = "ast.Var.Dot",
                    exp = { var = { name = "Point" } },
                    name = "new" } } })

        assert_expression_ast([[ List.new({}, nil) ]],
            { _tag = "ast.Exp.CallFunc",
                args = {
                  { _tag = "ast.Exp.Initlist" },
                  { _tag = "ast.Exp.Nil" } },
                exp = { var = {
                    _tag = "ast.Var.Dot",
                    exp = { var = { name = "List" } },
                    name = "new" } } })
    end)

    it("can parse record field access", function()
        assert_expression_ast([[ p.x ]],
            { _tag = "ast.Exp.Var", var = { _tag = "ast.Var.Dot",
                name = "x",
                exp = { _tag = "ast.Exp.Var", var = { _tag = "ast.Var.Name",
                    name = "p" } } } })

        assert_expression_ast([[ a.b[1].c ]],
            { _tag = "ast.Exp.Var", var = { _tag = "ast.Var.Dot",
                name = "c",
                exp = { _tag = "ast.Exp.Var", var = { _tag = "ast.Var.Bracket",
                    k = { value = 1 },
                    t = { _tag = "ast.Exp.Var", var = { _tag = "ast.Var.Dot",
                        name = "b",
                        exp = { _tag = "ast.Exp.Var", var = { _tag = "ast.Var.Name",
                            name = "a" } } } } } } } })
    end)

    it("can parse cast expressions", function()

        assert_expression_ast([[ foo as integer ]],
            { _tag = "ast.Exp.Cast",
                exp = { _tag = "ast.Exp.Var" },
                target = { _tag = "ast.Type.Name", name = "integer" } })

        assert_expression_ast([[ a.b[1].c as integer ]],
            { _tag = "ast.Exp.Cast",
                exp = { _tag = "ast.Exp.Var" },
                target = { _tag = "ast.Type.Name", name = "integer" } })

        assert_expression_ast([[ foo as { integer } ]],
            { _tag = "ast.Exp.Cast",
                exp = { _tag = "ast.Exp.Var" },
                target = { _tag = "ast.Type.Array" } })

        assert_expression_ast([[ 2 + foo as integer ]],
            { rhs = {
                _tag = "ast.Exp.Cast",
                exp = { _tag = "ast.Exp.Var" },
                target = { _tag = "ast.Type.Name", name = "integer" } }})

        assert_expression_ast([[ 1 as integer as any ]],
            { _tag = "ast.Exp.Cast",
                target = { _tag = "ast.Type.Name", name = "any" },
                exp = {
                    _tag = "ast.Exp.Cast",
                    target = { _tag = "ast.Type.Name", name = "integer" },
                    exp = {
                        _tag = "ast.Exp.Integer"
                    }}})
    end)

    it("does not allow parentheses in the LHS of an assignment", function()
        assert_statements_syntax_error([[ local (x) = 42 ]],
            "Expected a name before '('")
        assert_statements_syntax_error([[ (x) = 42 ]],
            "This expression is not an lvalue")
    end)

    it("uses specific error labels for some errors", function()

        assert_program_syntax_error([[
            export function () : int
            end
        ]], "Expected a name before '('")

        assert_program_syntax_error([[
            export function foo : int
            end
        ]], "Expected '(' before ':'")

        assert_program_syntax_error([[
            export function foo ( : int
            end
        ]], "Expected ')' before ':'")

        assert_program_syntax_error([[
            export function foo () :
                local x = 3
            end
        ]], "Unexpected 'local' while trying to parse a type")

        assert_program_syntax_error([[
            export function foo () : int
              local x = 3
              return x
        ]], "Expected 'end' before end of the file, to close the 'function' at line 1")

        assert_program_syntax_error([[
            export function foo(x, y) : int
            end
        ]], "Parameter 'x' is missing a type annotation")

        assert_program_syntax_error([[
            local x 3
        ]], "Expected '=' before number")

        assert_program_syntax_error([[
            local x =
        ]], "Unexpected end of the file while trying to parse an expression")

        assert_program_syntax_error([[
            record
        ]], "Expected a name before end of the file")

        assert_program_syntax_error([[
            typealias
        ]], "Expected a name before end of the file")

        assert_program_syntax_error([[
            typealias point
        ]], "Expected '=' before end of the file")

        assert_program_syntax_error([[
            typealias point =
        ]], "Unexpected end of the file while trying to parse a type")

        assert_program_syntax_error([[
            record A
                x : int
        ]], "Expected 'end' before end of the file, to close the 'record' at line 1")

        assert_program_syntax_error([[
            export function foo (a:int, ) : int
            end
        ]], "Expected a name before ')'")

        assert_program_syntax_error([[
            export function foo (a: ) : int
            end
        ]], "Unexpected ')' while trying to parse a type")

        assert_type_syntax_error([[ {int ]],
            "Expected '}'")

        assert_type_syntax_error([[ {a: float ]],
            "Expected '}'")

        assert_type_syntax_error([[
            {a: }
        ]], "Unexpected '}' while trying to parse a type")

        assert_type_syntax_error([[ (a,,,) -> b ]],
            "Unexpected ',' while trying to parse a type")

        assert_type_syntax_error([[ (a, b -> b  ]],
            "Expected ')'")

        assert_type_syntax_error([[ (a, b) -> = nil ]],
            "Unexpected '=' while trying to parse a type")

        assert_program_syntax_error([[
            record A
                x  int
            end
        ]], "Expected ':' before 'int'")

        assert_program_syntax_error([[
            record A
                x : function
            end
        ]], "Unexpected 'function' while trying to parse a type")

        assert_program_syntax_error([[
            export function f ( x : int) : string
                do
                return "42"
        ]], "Expected 'end' before end of the file, to close the 'do' at line 2")

        assert_statements_syntax_error([[
            while do
                x = x - 1
            end
        ]], "Unexpected 'do' while trying to parse an expression")

        assert_statements_syntax_error([[
            while x > 3
                x = x - 1
            end
        ]], "Expected 'do' before 'x'")

        assert_statements_syntax_error([[
            while x > 3 do
                x = x - 1
                return 42
            return 41
        ]], "Expected 'end' before 'return', to close the 'while' at line 2")

        assert_statements_syntax_error([[
            repeat
                x = x - 1
            end
        ]], "Expected 'until' before 'end', to close the 'repeat' at line 2")

        assert_statements_syntax_error([[
            repeat
                x = x - 1
            until
        ]], "Unexpected 'end' while trying to parse an expression")

        assert_statements_syntax_error([[
            if then
                x = x - 1
            end
        ]], "Unexpected 'then' while trying to parse an expression")

        assert_statements_syntax_error([[
            if x > 10
                x = x - 1
            end
        ]], "Expected 'then' before 'x'")

        assert_statements_syntax_error([[
            if x > 10 then
                x = x - 1
                return 42
            return 41
        ]], "Expected 'end' before 'return', to close the 'if' at line 2")

        assert_statements_syntax_error([[
            for = 1, 10 do
            end
        ]], "Expected a name before '='")

        assert_statements_syntax_error([[
            for x  1, 10 do
            end
        ]], "Unexpected number while trying to parse a for loop")

        assert_statements_syntax_error([[
            for x = , 10 do
            end
        ]], "Unexpected ',' while trying to parse an expression")

        assert_statements_syntax_error([[
            for x = 1 10 do
            end
        ]], "Expected ',' before number")

        assert_statements_syntax_error([[
            for x = 1, do
            end
        ]], "Unexpected 'do' while trying to parse an expression")

        assert_statements_syntax_error([[
            for x = 1, 10, do
            end
        ]], "Unexpected 'do' while trying to parse an expression")

        assert_statements_syntax_error([[
            for x = 1, 10, 1
            end
        ]], "Expected 'do' before 'end'")

        assert_statements_syntax_error([[
            for x = 1, 10, 1 do
                return 42
            return 41
        ]], "Expected 'end' before 'return', to close the 'for' at line 2")

        assert_statements_syntax_error([[
            for k, in ipairs(t) do
                k = 1
            end
        ]], "Expected a name before 'in'")

        assert_statements_syntax_error([[
            for k v in ipairs(t) do
                v = 1
            end
        ]], "Unexpected 'v' while trying to parse a for loop")

        assert_statements_syntax_error([[
            for in ipairs(t) do
                local v = 1
            end
        ]], "Expected a name before 'in'")

        assert_statements_syntax_error([[
            for k, v in ipairs(t)
                k = 1
            end
        ]], "Expected 'do' before 'k'")

        assert_statements_syntax_error([[
            local = 3
        ]], "Expected a name before '='")

        assert_statements_syntax_error([[
            local x =
        ]], "Unexpected 'end' while trying to parse an expression")

        assert_statements_syntax_error([[
            x =
        ]], "Unexpected 'end' while trying to parse an expression")

        assert_statements_syntax_error([[
            if x > 1 then
                x = x - 1
            elseif then
            end
        ]], "Unexpected 'then' while trying to parse an expression")

        assert_statements_syntax_error([[
            if x > 1 then
                x = x - 1
            elseif x > 0
            end
        ]], "Expected 'then' before 'end'")

        assert_expression_syntax_error([[ 1 + ]],
            "Unexpected 'end' while trying to parse an expression")

        assert_expression_syntax_error([[ obj:() ]],
            "Expected a name before '('")

        assert_expression_syntax_error([[ obj:f + 1 ]],
            "Expected '(' before '+'")

        assert_expression_syntax_error([[ y[] ]],
            "Unexpected ']' while trying to parse an expression")

        assert_expression_syntax_error([[ y[1 ]],
            "Expected ']' before 'end'")

        assert_expression_syntax_error([[ y.() ]],
            "Expected a name before '('")

        assert_expression_syntax_error([[ () ]],
            "Unexpected ')' while trying to parse an expression")

        assert_expression_syntax_error([[ (42 ]],
            "Expected ')' before 'end'")

        assert_expression_syntax_error([[ f(42 ]],
            "Expected ')' before 'end'")

        assert_expression_syntax_error([[ f(42,) ]],
            "Unexpected ')' while trying to parse an expression")

        assert_expression_syntax_error([[ y{42 ]],
            "Expected '}' before 'end'")

        assert_expression_syntax_error([[ y{42,,} ]],
            "Unexpected ',' while trying to parse an expression")

        assert_expression_syntax_error([[ foo as ]],
            "Unexpected 'end' while trying to parse a type")
    end)

    it("catches break statements outside loops", function()
        assert_program_syntax_error([[
            export function fn()
                break
            end
        ]], "break statement outside of a loop")
    end)

    it("catches break statements outside loops but inside other statements", function()
        assert_program_syntax_error([[
            export function fn(x:boolean)
                do
                    if x then
                        break
                    else
                        break
                    end
                end
            end
        ]], "break statement outside of a loop")
    end)

end)
