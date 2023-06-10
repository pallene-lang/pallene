-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

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

local function parse(code)
    return driver.compile_internal("__test__.pln", code, "ast")
end

--
-- Assertions for full programs
--

local function assert_parses_successfuly(program_str)
    local prog_ast, errors = parse(program_str)
    if not prog_ast then
        error(string.format("unexpected Pallene syntax error: %s", errors[1]))
    end
    return prog_ast
end

local function assert_program_error(program_str, expected_error)
    local prog_ast, errors = parse(program_str)
    if prog_ast then
        error(string.format(
            "expected Pallene syntax error %s but parsed successfuly",
            expected_error))
    end
    assert.matches(expected_error, errors[1], 1, true)
end

--
-- Assertions for toplevel components
--

local function toplevel_test_program(s)
    return util.render([[
        local m = {}
        $TL
        return m
    ]], { TL = s })
end

local function assert_toplevel_ast(code, expected_ast)
    local program_ast = assert_parses_successfuly(toplevel_test_program(code))
    local tl_ast = program_ast.tls[1]
    assert_is_subset(expected_ast, tl_ast)
end

local function assert_toplevel_error(code, expected_error)
    assert_program_error(toplevel_test_program(code), expected_error)
end

--
-- Assertions for types
--

local function type_test_program(s)
    return (util.render([[
        local m = {}
        local x: ${TYPE} = nil
        return m
    ]], { TYPE = s } ))
end

local function assert_type_ast(code, expected_ast)
    local program_ast = assert_parses_successfuly(type_test_program(code))
    local type_ast = program_ast.tls[1].stats[1].decls[1].type
    assert_is_subset(expected_ast, type_ast)
end

--
-- Assertions for statements
--

local function statements_test_program(s)
    return (util.render([[
        local m = {}
        local function foo()
            ${STATS}
        end
        return m
    ]], { STATS = s }))
end

local function assert_statements_ast(code, expected_ast)
    local program_ast = assert_parses_successfuly(statements_test_program(code))
    local stats_ast = program_ast.tls[1].stats[1].funcs[1].value.body.stats
    assert_is_subset(expected_ast, stats_ast)
end

local function assert_statements_error(code, expected_error)
    assert_program_error(statements_test_program(code), expected_error)
end

--
-- Assertions for expressions
--

local function expression_test_program(s)
    return (util.render([[
        local m = {}
        local function foo()
            x = ${EXPR}
        end
        return m
    ]], { EXPR = s }))
end

local function assert_expression_ast(code, expected_ast)
    local program_ast = assert_parses_successfuly(expression_test_program(code))
    local exp_ast = program_ast.tls[1].stats[1].funcs[1].value.body.stats[1].exps[1]
    assert_is_subset(expected_ast, exp_ast)
end

local function assert_expression_error(code, expected_error)
    assert_program_error(expression_test_program(code), expected_error)
end


-- Organization of the Parser Test Suite
-- --------------------------------------
--
-- Try to order the tests by the order that things appear in parser.lua.
-- This way, it's easier to know if a test case is missing.
--
-- Where possible, prefer testing a working program in the coder instead of looking at the AST.
-- The AST changes more often than the surface syntax, which means that AST tests tend to break.
-- Reserve the AST tests for tricky things such as operator precedence.

describe("Parser /", function()

    do
        local ORIGINAL_FORMAT_LEVEL

        setup(function()
            -- Print the whole AST when it doesn't match, instead of just a handful of nodes.
            -- A depth of 100 should be sufficient. In the past we also tried using -1 to remove the
            -- limit but that could get stuck in an infinite loop due to self-referential tables.
            ORIGINAL_FORMAT_LEVEL = assert:get_parameter("TableFormatLevel")
            assert:set_parameter("TableFormatLevel", 100)
        end)

        teardown(function()
            assert:set_parameter("TableFormatLevel", ORIGINAL_FORMAT_LEVEL)
        end)
    end

    describe("Programs", function()

        it("must not be empty", function()
        end)

        it("must start with a module declaration", function()
            assert_program_error([[
            ]], "must begin with a module declaration")

            assert_program_error([[
                return m
            ]], "must begin with a module declaration")
        end)

        it("the module declaration must be valid", function()
            assert_program_error([[
                local m, n = {}, {}
            ]], "cannot use a multiple-assignment to declare the module table")

            assert_program_error([[
                local m : foo = {}
            ]], "if the module variable has a type annotation, it must be exactly 'module'")

            assert_program_error([[
                local m = 123
            ]], "the module initializer must be exactly {}")
        end)

        it("must end with a valid return statement", function()
            assert_program_error([[
                local m = {}
            ]], "must end by returning the module table")

            assert_program_error([[
                local m = {}
                return m
                local x = 1
            ]], "the module return statement must be the last thing in the file")

            assert_program_error([[
                local m: module = {}
                return m, m
            ]], "the module return statement must return a single value")

            assert_program_error([[
                local m: module = {}
                local i: integer = 2
                return i
            ]], "must return exactly the module variable 'm'")
        end)

        it("can have semi-colons at the toplevel", function ()
            assert_parses_successfuly([[
                local m: module = {};
                record Number
                    num: integer;
                end;
                return m;
            ]])
        end)

    end)

    --
    -- Toplevel
    --

    describe("Record declarations", function()

        it("can be empty", function()
            assert_toplevel_ast([[ record Empty end ]], {
                _tag = "ast.Toplevel.Record",
                name = "Empty",
                field_decls = {}
            })
        end)

        it("can use semocolons as a separator", function()
            assert_toplevel_ast([[ record Point x: float; y: float; end ]], {
                _tag = "ast.Toplevel.Record",
                name = "Point",
                field_decls = {
                    { name = "x" },
                    { name = "y" }
                }
            })
        end)
    end)

    describe("Toplevel statements", function()

        it("only allow certain statements", function()
            assert_toplevel_error([[
                while true do end
            ]], "toplevel statements can only be Returns, Declarations or Assignments")
        end)
    end)

    describe("Function types", function()

        it("can have type lists of length = 0", function()
            assert_type_ast("() -> ()", {
                _tag = "ast.Type.Function",
                arg_types = {},
                ret_types = {},
            })
        end)

        it("can have type lists of length = 1", function()
            assert_type_ast("(a) -> (b)", {
                _tag = "ast.Type.Function",
                arg_types = { { _tag = "ast.Type.Name", name = "a" } },
                ret_types = { { _tag = "ast.Type.Name", name = "b" } },
            })
        end)

        it("can have type lists of length >= 2 ", function()
            assert_type_ast("(a,b) -> (c,d,e)", {
                _tag = "ast.Type.Function",
                arg_types = {
                    { _tag = "ast.Type.Name", name = "a" },
                    { _tag = "ast.Type.Name", name = "b" },
                },
                ret_types = {
                    { _tag = "ast.Type.Name", name = "c" },
                    { _tag = "ast.Type.Name", name = "d" },
                    { _tag = "ast.Type.Name", name = "e" },
                },
            })
        end)

        it("can omit the optional parenthesis", function()
            assert_type_ast("a -> b", {
                _tag = "ast.Type.Function",
                arg_types = { { _tag = "ast.Type.Name", name = "a" } },
                ret_types = { { _tag = "ast.Type.Name", name = "b" } },
            } )
        end)

        it("are right-associative", function()
            local ast1 = {
                _tag = "ast.Type.Function",
                arg_types = { { _tag = "ast.Type.Name", name = "a" }, },
                ret_types = { {
                    _tag = "ast.Type.Function",
                    arg_types = { { _tag = "ast.Type.Name", name = "b" } },
                    ret_types = { { _tag = "ast.Type.Name", name = "c" } },
                } }
            }

            local ast2 = {
                _tag = "ast.Type.Function",
                arg_types = { {
                    _tag = "ast.Type.Function",
                    arg_types = { { _tag = "ast.Type.Name", name = "a" } },
                    ret_types = { { _tag = "ast.Type.Name", name = "b" } },
                } },
                ret_types = { { _tag = "ast.Type.Name", name = "c" } },
            }

            assert_type_ast("a -> b -> c",   ast1)
            assert_type_ast("a -> (b -> c)", ast1)
            assert_type_ast("(a -> b) -> c", ast2)
        end)

        it("have higher precedence than ','", function()
            assert_type_ast("(a, b -> c, d) -> e", {
                _tag = "ast.Type.Function",
                arg_types = {
                    { _tag = "ast.Type.Name", name = "a" },
                    {
                        _tag = "ast.Type.Function",
                        arg_types = { { _tag = "ast.Type.Name", name = "b" } },
                        ret_types = { { _tag = "ast.Type.Name", name = "c" } },
                    },
                    { _tag = "ast.Type.Name", name = "d" }
                },
                ret_types = { { _tag = "ast.Type.Name", name = "e" } },
            })
        end)
    end)

    --
    -- Stat
    --

    describe("Break statements", function()

        it("are not allowed outside a loop", function()
            assert_statements_error([[
                do
                    if x then
                        break
                    end
                end
            ]], "break statement outside of a loop")
        end)

        it("are not allowed outside a loop (using function stat)", function()
            assert_statements_error([[
                while true do
                    local function inner()
                        break
                    end
                end
            ]], "break statement outside of a loop")
        end)

        it("are not allowed outside a loop (using function exp)", function()
            assert_statements_error([[
                while true do
                    local inner: () -> () = function() break end
                end
            ]], "break statement outside of a loop")
        end)

    end)

    describe("Return statements", function()

        it("can be empty", function()
            assert_statements_ast("return", {
                { _tag = "ast.Stat.Return", exps = {} }
            })
        end)

        it("can be followed by a single semicolon", function()
            assert_statements_ast("return 10;", {
                { _tag = "ast.Stat.Return", exps = { { _tag = "ast.Exp.Integer", value = 10 } } }
            })
        end)

        it("cannot be followed by a multiple semicolons", function()
            assert_program_error([[
                local m: module = {}
                return m;;
            ]], "the module return statement must be the last thing in the file")
        end)

        it("must be the last statement in the block", function()
            assert_statements_error([[
                return 10
                return 11
            ]], "expected 'end' before 'return', to close the 'function' at line 2")
        end)
    end)

    describe("Function statements", function()

        it("must have a name", function()
            assert_toplevel_error([[
                local function (): integer
                end
            ]], "expected a name before '('")
        end)

        it("disallow multiple levels of '.'", function()
            assert_toplevel_error([[
                function m.f.g()
                end
            ]], "more than one dot in the function name is not allowed")
        end)

        it("disallow complex names for local functions (1/2)", function()
            assert_toplevel_error([[
                local function foo.bar()
                end
            ]], "local function name has a '.'")
        end)

        it("disallow complex names for local functions (2/2)", function()
            assert_toplevel_error([[
                local function foo:bar()
                end
            ]], "local function name has a ':'")
        end)

        it("disallow too many function parameters", function ()
            local t_params = {}
            for i = 1, 201 do
                t_params[i] = "a"..i..": integer"
            end
            local params = table.concat(t_params, ", ")
            assert_toplevel_error([[
                function m.f(]]..params..[[): integer
                    return 1
                end
            ]], "too many parameters (limit is 200)")
        end)

        it("must have argument type annotations (argument)", function()
            assert_toplevel_error([[
                local function foo(x): integer
                    return 10
                end
            ]], "parameter 'x' is missing a type annotation")
        end)
    end)

    describe("LetRec", function()

        it("can have a forward declaration", function()
            assert_toplevel_ast([[
                function m.f() end
                function m.g() end
                local x, y
                function x() end
                function m.h() end
                function y() end
            ]], {
                _tag = "ast.Toplevel.Stats",
                stats = {
                    {
                        _tag = "ast.Stat.Functions",
                        declared_names = {},
                        funcs = {
                            { module = "m", name = "f" },
                            { module = "m", name = "g" },
                        },
                    },
                    {
                        _tag = "ast.Stat.Functions",
                        declared_names = { ["x"] = true, ["y"] = true },
                        funcs = {
                            { module = false, name = "x" },
                            { module = "m",   name = "h" },
                            { module = false, name = "y" },
                        },
                    }
                },
            })
        end)

        it("is interrupted by a local function", function()
            assert_toplevel_ast([[
                function m.f() end
                function m.g() end
                local function x() end
                local function y() end
                function m.h() end
            ]], {
                _tag = "ast.Toplevel.Stats",
                stats = {
                    {
                        _tag = "ast.Stat.Functions",
                        declared_names = {},
                        funcs = {
                            { module = "m", name = "f" },
                            { module = "m", name = "g" },
                        },
                    },
                    {
                        _tag = "ast.Stat.Functions",
                        declared_names = { ["x"] = true },
                        funcs = {
                            { module = false, name = "x" },
                        },
                    },
                    {
                        _tag = "ast.Stat.Functions",
                        declared_names = { ["y"] = true },
                        funcs = {
                            { module = false, name = "y" },
                        },
                    },
                    {
                        _tag = "ast.Stat.Functions",
                        declared_names = {},
                        funcs = {
                            { module = "m", name = "h" },
                        },
                    }
                },
            })
        end)

        it("does not allow type annotations in the forward declaration", function()
            assert_toplevel_error([[
                local f: () -> ()
                function f() end
            ]], "type annotations are not allowed in a function forward declaration")
        end)

        it("does not allow repeated names in the forward declaration", function()
            assert_toplevel_error([[
                local f,f,g
                function f() end
                function g() end
            ]], "duplicate forward declaration for 'f'")
        end)

        it("complains if a global function was not forward declared", function()
            assert_toplevel_error([[
                local f
                function f() end
                function g() end
            ]], "function 'g' was not forward declared")
        end)

        it("catches a missing function definition", function()
            assert_toplevel_error([[
                local f, g
                function f() end
            ]], "missing a function definition for 'g'")
        end)
    end)

    -- TODO: Move this test to the type checker?
    describe("Toplevel assignments", function()

        it("are only allowed to module fields", function()
            assert_toplevel_error([[
                x = 17
            ]], "toplevel assignments are only possible with module fields")
        end)
    end)

    describe("Function call statements", function()

        it("disallows too many arguments", function ()
            local t_args = {}
            for i = 1, 201 do
                t_args[i] = i
            end
            local args = table.concat(t_args, ", ")
            assert_statements_error([[
                f(]]..args..[[)
            ]], "too many arguments (limit is 200)")
        end)

        it("are the only expression allowed as a statement (1/2)", function()
            assert_statements_error([[
                (f)
            ]], "this expression in a statement position is not a function call")
        end)

        it("are the only expression allowed as a statement (2/2)", function()
            assert_statements_error([[
                1 + 1
            ]], "expected 'end' before number, to close the 'function'")
        end)
    end)

    --
    -- Var
    --
    --

    describe("Lvalue", function()

        it("cannot be any expression", function()
            assert_statements_error([[
                (x) = 42
            ]], "this expression is not an lvalue")
        end)
    end)

    --
    -- Expr
    --

    -- In Lua, parenthesis can matter for multiple function returns
    describe("Parenthesized expressions", function()

        it("are preserved in the AST", function()
            assert_expression_ast("((1))",
                { _tag = "ast.Exp.Paren",
                    exp = { _tag = "ast.Exp.Paren",
                        exp = { _tag = "ast.Exp.Integer", value = 1 }}})
        end)
    end)

    describe("Table constructors", function()

        it("can be empty", function()
            assert_expression_ast("{}",
                { _tag = "ast.Exp.InitList", fields = {} })
        end)

        it("can use commas", function()
            assert_expression_ast("{10,20,30}",
                { _tag = "ast.Exp.InitList", fields = {
                    { exp = { value = 10 } },
                    { exp = { value = 20 } },
                    { exp = { value = 30 } }, }})
        end)

        it("can use semicolons", function()
            assert_expression_ast("{40;50;60;}",
                { _tag = "ast.Exp.InitList", fields = {
                    { exp = { value = 40 } },
                    { exp = { value = 50 } },
                    { exp = { value = 60 } }, }})
        end)
    end)

    describe("Suffixed expressions", function()

        it("have the right precedence", function()
            assert_expression_ast([[ - x(1)(2)[3].f ^ 4]], {
                op = "-",
                exp = {
                    op = "^",
                    lhs = {
                        _tag = "ast.Exp.Var",
                        var = {
                            _tag ="ast.Var.Dot",
                            exp = {
                                _tag = "ast.Exp.Var",
                                var = {
                                    _tag = "ast.Var.Bracket",
                                    t = {
                                        _tag = "ast.Exp.CallFunc",
                                        exp = {
                                            _tag = "ast.Exp.CallFunc",
                                            exp = { _tag = "ast.Exp.Var", var = { name = "x" } },
                                            args = { { value = 1 }},
                                        },
                                        args = { { value = 2 } },
                                    },
                                    k = { value = 3 },
                                },
                            },
                            name = "f",
                        },
                    },
                    rhs = { value = 4 },
                },
            })
        end)
    end)

    describe("Function expressions", function()

        it("cannot have a name", function()
            assert_expression_error([[ function f() end ]], "expected '(' before 'f'")
        end)

        it("cannot have argument annotations", function()
            assert_expression_error([[ function (x:integer) return x+1 end ]],
            "Function expressions cannot be type annotated")
        end)

        it("cannot have return type annotation", function()
            assert_expression_error([[ function (x) : integer return x+1 end ]],
            "Function expressions cannot be type annotated")
        end)

    end)

    describe("Function calls without parenthesis", function()

        it("for string literals", function()
            assert_expression_ast([[ f "qwe" ]], {
                _tag = "ast.Exp.CallFunc",
                args = { { _tag = "ast.Exp.String", value = "qwe" } }
            })
        end)

        it("for table literals", function()
            assert_expression_ast([[ f {} ]], {
                _tag = "ast.Exp.CallFunc",
                args = { { _tag = "ast.Exp.InitList" } }
            })
        end)
    end)

    describe("Cast expressions", function()

        it("have lower precedence than suffixes", function()
            assert_expression_ast([[ a.b[1].c as integer ]], {
                _tag = "ast.Exp.Cast",
                exp = { _tag = "ast.Exp.Var" },
                target = { _tag = "ast.Type.Name", name = "integer" },
            })
        end)

        it("have higherprecedence than arithmetic", function()
            assert_expression_ast([[ 2 + foo as integer ]], {
                _tag = "ast.Exp.Binop",
                lhs = { value = 2 },
                rhs = {
                    _tag = "ast.Exp.Cast",
                    exp = { _tag = "ast.Exp.Var" },
                    target = { _tag = "ast.Type.Name", name = "integer" },
                }
            })
        end)

        it("can be nested", function()
            assert_expression_ast([[ 1 as integer as any ]], {
                _tag = "ast.Exp.Cast",
                target = { _tag = "ast.Type.Name", name = "any" },
                exp = {
                    _tag = "ast.Exp.Cast",
                    target = { _tag = "ast.Type.Name", name = "integer" },
                    exp = { value = 1 },
                },
            })
        end)
    end)

    describe("Operator precedence /", function()

        it("Boolean operators", function()
            assert_expression_ast([[not 1 or 2 and 3 and 4]], {
                op = "or",
                lhs = { op = "not", exp = { value = 1 } },
                rhs = {
                    op = "and",
                    lhs = {
                        op = "and",
                        lhs = { value = 2 },
                        rhs = { value = 3 }
                    },
                    rhs = { value = 4}
                },
            })
        end)

        it("Relational operators are left associative", function()
            assert_expression_ast([[1 == 2 == 3]], {
                op = "==",
                lhs = {
                    op = "==",
                    lhs = { value = 1 },
                    rhs = { value = 2 },
                },
                rhs = { value = 3 }
            })
        end)

        it("Bitwise operators have the right precedence", function()
            assert_expression_ast([[~~1 ~ 2 << 3 >> 4 | 5 & 6]], {
                op = "|",
                lhs = {
                    op = "~",
                    lhs = { op = "~", exp = { op = "~", exp = { value = 1 } } },
                    rhs = {
                        op = ">>",
                        lhs = {
                            op = "<<",
                            lhs = { value = 2 },
                            rhs = { value = 3 },
                        },
                    },
                },
                rhs = {
                    op = "&",
                    lhs = { value = 5 },
                    rhs = { value = 6 },
                },
            })
        end)

        it("Arithmetic operators have the right precedence", function()
            assert_expression_ast([[- -1 / 2 + 3 * # "a"]], {
                op = "+",
                lhs = {
                    op = "/",
                    lhs = { op = "-", exp = { op = "-", exp = { value = 1 } } },
                    rhs = { value = 2 },
                },
                rhs = {
                    op = "*",
                    lhs = { value = 3 },
                    rhs = { op = "#", exp = { value = "a" } },
                },
            })
        end)

        it("Concatenation is right-associative and lower precedence than prefix ops", function()
            assert_expression_ast([[-1 .. -2 .. -3]], {
                op = "..",
                lhs = { op = "-", exp = { value = 1 } },
                rhs = {
                    op = "..",
                    lhs = { op = "-", exp = { value = 2 } },
                    rhs = { op = "-", exp = { value = 3 } },
                },
            })
        end)

        it("Exponentiation is right-associative and higher precedence than prefix ops", function()
            assert_expression_ast([[-1 ^ -2 ^ 3 * 4]], {
                op = "*",
                lhs = {
                    op = "-",
                    exp = {
                        op = "^",
                        lhs = { value = 1 },
                        rhs = {
                            op = "-",
                            exp = {
                                op = "^",
                                lhs = { value = 2 },
                                rhs = { value = 3 },
                            },
                        },
                    },
                },
                rhs = { value = 4 },
            })
        end)
    end)

    describe("Missing 'end' errors", function()

        it("point to the opening delimiter", function()
            assert_program_error([[
                local m = {}
                local function foo()

                return m
            ]], "expected 'end' before end of the file, to close the 'function' at line 2")
        end)

        it("use indentation to find the actual location of the error", function()
            assert_program_error([[
                local m = {}
                local function foo()
                    if true then
                end
                return m
            ]], "expected 'end' to close 'if' at line 3, before this less indented 'end'")
        end)

    end)
end)
