-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local ast = require "pallene.ast"
local util = require "pallene.util"

-- This module implements the Pallene parser. It is loosely based on the Lua parser from lparser.c,
-- including the error messages. We use an LL(2) grammar, which requires one extra token of
-- lookahead.

local Parser = util.Class()

function Parser:init(lexer)
    self.lexer = lexer
    self.loop_depth = 0
    self.next = false -- Token
    self.look = false -- Token
    self:_advance(); self:_advance()
end

function Parser:_advance()
    local tok, err = self.lexer:next()
    if not tok then
        self:syntax_error(self.lexer:loc(), "%s", err)
    end
    local ret = self.next
    self.next = self.look
    self.look = tok
    return ret
end

-- Check the next token without consuming it
function Parser:peek(name)
    assert(name)
    assert(self.next.name)
    return (name == self.next.name)
end

-- Check the next-next token without consuming it
function Parser:doublepeek(name)
    assert(name)
    assert(self.look.name)
    return (name == self.look.name)
end

-- Tries to match a token with the given name.
function Parser:try(name)
    assert(name)
    assert(name ~= "EOF")
    if self:peek(name) then
        return self:_advance()
    else
        return false
    end
end

-- [E]xpect a token of a given type.
-- If the name is not provided, match whatever token we just peek-ed.
-- If the optional open_tok is provided then we are matching a closing token ({}, (), do end, etc).
function Parser:e(name, open_tok)
    name = name or self.next.name
    local tok = self:try(name)
    if tok then
        return tok
    else
        self:wrong_token_error(name, open_tok)
    end
end

function Parser:loop_begin()
    self.loop_depth = self.loop_depth + 1
end

function Parser:loop_end()
    self.loop_depth = self.loop_depth - 1
end

--
-- Toplevel
--

function Parser:Program()
    local tls = {}
    while not self:peek("EOF") do
        table.insert(tls, self:Toplevel())
    end
    return tls
end

function Parser:Toplevel()
    if self:peek("typealias") then
        local start = self:e()
        local id    = self:e("NAME")
        local _     = self:e("=")
        local typ   = self:Type()
        return ast.Toplevel.Typealias(start.loc, id.value, typ, self.next.loc)

    elseif self:peek("record") then
        local start  = self:e()
        local id     = self:e("NAME")
        local fields = {}
        while self:peek("NAME") do
            local decl = self:Decl()
            if not decl.type then self:forced_syntax_error(":") end
            local _ = self:try(";")
            table.insert(fields, decl)
        end
        self:e("end", start)
        return ast.Toplevel.Record(start.loc, id.value, fields, self.next.loc)

    else
        local visibility
        if self:peek("local") or self:peek("export") then
            visibility = self:e()
        else
            visibility = false
        end

        if self:peek("function") then
            local start    = self:e()
            local id       = self:e("NAME")
            local oparen   = self:e("(")
            local params   = self:DeclList()
            local _        = self:e(")", oparen)
            local rt_colon = self.next.loc
            local rt_types = self:try(":") and self:RetTypes() or {}
            local rt_end   = self.next.loc
            local block    = self:Block()
            local _        = self:e("end", start)

            if not visibility then
                self:syntax_error(start.loc,
                    "Function declarations must have a 'local' or 'export' modifier")
            end

            for _, decl in ipairs(params) do
                if not decl.type then
                    self:syntax_error(decl.loc,
                        "Parameter '%s' is missing a type annotation", decl.name)
                end
            end

            local arg_types = {}
            for i, decl in ipairs(params) do
                arg_types[i] = decl.type
            end
            local func_typ = ast.Type.Function(visibility.loc, arg_types, rt_types)

            return ast.Toplevel.Func(
                visibility.loc, visibility.name,
                ast.Decl.Decl(visibility.loc, id.value, false, func_typ, false),
                ast.Exp.Lambda(visibility.loc, params, block),
                rt_colon, rt_end)

        elseif self:peek("NAME") then
            local decls = self:DeclList(); assert(#decls > 0)
            local _     = self:e("=")
            local exps  = self:ExpList1();

            if not visibility then
                self:syntax_error(decls[1].loc,
                    "Variable declarations must have a 'local' or 'export' modifier")
            end

            return ast.Toplevel.Var(visibility.loc, visibility.name, decls, exps)

        else
            self:unexpected_token_error("a toplevel declaration")
        end
    end
end

--
-- Types
--

function Parser:Type()
    if self:peek("(") then
        local loc = self.next.loc
        local aa  = self:TypeList()
        local _   = self:e("->");
        local bb  = self:RetTypes()
        return ast.Type.Function(loc, aa, bb)
    else
        local a = self:SimpleType()
        if self:try("->") then
            local bb  = self:RetTypes()
            return ast.Type.Function(a.loc, {a}, bb)
        else
            return a
        end
    end
end

function Parser:TypeList()
    local ts = {}
    local open = self:e("(");
    if not self:peek(")") then
        table.insert(ts, self:Type())
        while self:try(",") do
            table.insert(ts, self:Type())
        end
    end
    self:e(")", open)
    return ts
end

function Parser:RetTypes()
    if self:peek("(") then
        local loc = self.next.loc
        local aa = self:TypeList()
        if self:try("->") then
            local bb  = self:RetTypes()
            return { ast.Type.Function(loc, aa, bb) }
        else
            return aa
        end
    else
        return { self:Type() }
    end
end

function Parser:SimpleType()
    if self:peek("nil") then
        local tok = self:e()
        return ast.Type.Nil(tok.loc)

    elseif self:peek("boolean") then
        local tok = self:e()
        return ast.Type.Boolean(tok.loc)

    elseif self:peek("integer") then
        local tok = self:e()
        return ast.Type.Integer(tok.loc)

    elseif self:peek("float") then
        local tok = self:e()
        return ast.Type.Float(tok.loc)

    elseif self:peek("string") then
        local tok = self:e()
        return ast.Type.String(tok.loc)

    elseif self:peek("any") then
        local tok = self:e()
        return ast.Type.Any(tok.loc)

    elseif self:peek("NAME") then
        local tok = self:e()
        return ast.Type.Name(tok.loc, tok.value)

    elseif self:peek("{") then
        local open = self:e()
        if self:peek("}") or (self:peek("NAME") and self:doublepeek(":")) then
            local fields = {}
            repeat
                if self:peek("}") then break end
                local id  = self:e("NAME")
                local _   = self:e(":")
                local typ = self:Type()
                table.insert(fields, { name = id.value, type = typ })
            until not self:FieldSep()
            self:e("}", open)
            return ast.Type.Table(open.loc, fields)
        else
            local typ = self:Type()
            local _   = self:e("}", open)
            return ast.Type.Array(open.loc, typ)
        end
    else
        self:unexpected_token_error("a type")
    end
end

--
-- Decls
--

function Parser:Decl()
    local id = self:e("NAME")
    if self:peek(":") then
        local colon = self:e()
        local typ   = self:Type()
        return ast.Decl.Decl(id.loc, id.value, colon.loc, typ, self.next.loc)
    else
        return ast.Decl.Decl(id.loc, id.value, false, false, false)
    end
end

function Parser:DeclList()
    local decls = {}
    if self:peek("NAME") then
        table.insert(decls, self:Decl())
        while self:try(",") do
            table.insert(decls, self:Decl())
        end
    end
    return decls
end

--
-- Statements
--

function Parser:block_follow()
    return self:peek("end") or
           self:peek("else") or
           self:peek("elseif") or
           self:peek("until")
end

function Parser:Block()
    local stats = {}
    while not self:block_follow() do
        if self:try(";") then
            -- skip empty statement
        else
            local stat = self:Stat()
            local _    = self:try(";")
            table.insert(stats, stat)
            if stat._tag == "ast.Stat.Return" then
                break
            end
        end
    end
    return ast.Stat.Block(false, stats)
end

function Parser:Stat()
    if self:peek("do") then
        local start = self:e()
        local body  = self:Block()
        local _     = self:e("end", start)
        return body

    elseif self:peek("while") then
        local start = self:e()
        local cond  = self:Exp()
        local _     = self:e("do"); self:loop_begin()
        local body  = self:Block(); self:loop_end()
        local _     = self:e("end", start)
        return ast.Stat.While(start.loc, cond, body)

    elseif self:peek("repeat") then
        local start = self:e();     self:loop_begin()
        local body  = self:Block(); self:loop_end()
        local _     = self:e("until", start);
        local cond  = self:Exp()
        return ast.Stat.Repeat(start.loc, body, cond)

    elseif self:peek("if") then
        local if_start = self:e()
        local if_exp   = self:Exp()
        local _        = self:e("then")
        local if_body  = self:Block()

        local eifs = {}
        while self:peek("elseif") do
            local ei_start = self:e()
            local ei_exp   = self:Exp()
            local _        = self:e("then")
            local ei_body  = self:Block()
            table.insert(eifs, {ei_start.loc, ei_exp, ei_body})
        end

        local e_body
        if self:try("else") then
            e_body = self:Block()
        else
            e_body = ast.Stat.Block(false, {})
        end

        self:e("end", if_start)

        for i = #eifs, 1, -1 do
            local eif = eifs[i]
            e_body = ast.Stat.If(eif[1], eif[2], eif[3], e_body)
        end
        return ast.Stat.If(if_start.loc, if_exp, if_body, e_body)

    elseif self:peek("for") then
        local start = self:e()
        local decl1 = self:Decl()

        if self:try("=") then
            local init  = self:Exp()
            local _     = self:e(",")
            local limit = self:Exp()
            local step  = self:try(",") and self:Exp()
            local _     = self:e("do"); self:loop_begin()
            local body  = self:Block(); self:loop_end()
            local _     = self:e("end", start)
            return ast.Stat.For(start.loc, decl1, init, limit, step, body)

        elseif self:peek(",") or self:peek("in") then
            local decls = {decl1}
            while self:try(",") do
                table.insert(decls, self:Decl())
            end
            local _    = self:e("in")
            local exps = self:ExpList1()
            local _    = self:e("do"); self:loop_begin()
            local body = self:Block(); self:loop_end()
            local _    = self:e("end", start)
            self:syntax_error(start.loc, "for-in loops are not implemented yet")
            return ast.Stat.ForIn(start.loc, decls, exps, body)

        else
            self:unexpected_token_error("a for loop")

        end

    elseif self:peek("local") then
        local start = self:e()
        local decls = self:DeclList(); if #decls == 0 then self:forced_syntax_error("NAME") end
        local exps  = self:try("=") and self:ExpList1() or {}
        return ast.Stat.Decl(start.loc, decls, exps)

    elseif self:peek("break") then
        local start = self:e()
        if self.loop_depth > 0 then
            return ast.Stat.Break(start.loc)
        else
            self:syntax_error(start.loc, "break statement outside of a loop")
        end

    elseif self:peek("return") then
        local start = self:e()
        if self:peek(";") or self:block_follow() then
            return ast.Stat.Return(start.loc, {})
        else
            return ast.Stat.Return(start.loc, self:ExpList1())
        end

    else
        -- Assignment or function call
        local exp = self:SuffixedExp(true)
        if self:peek("=") or self:peek(",") then
            local lhs = { self:to_var(exp) }
            while self:try(",") do
                table.insert(lhs, self:to_var(self:SuffixedExp(false)))
            end
            local op  = self:e("=")
            local rhs = self:ExpList1()
            return ast.Stat.Assign(op.loc, lhs, rhs)

        else
            if exp._tag == "ast.Exp.CallFunc" or exp._tag == "ast.Exp.CallMethod" then
                return ast.Stat.Call(exp.loc, exp)
            else
                self:syntax_error(exp.loc,
                    "This expression in a statement position is not a function call")
            end
        end
    end
end

--
-- Vars
--

-- Can this expression appear in an assignment position?
function Parser:to_var(exp)
    if exp._tag == "ast.Exp.Var" then
        return exp.var
    else
        self:syntax_error(exp.loc, "This expression is not an lvalue")
    end
end

--
-- Expressions
--

function Parser:PrimaryExp(is_statement)
    if self:peek("NAME") then
        local id = self:e()
        return ast.Exp.Var(id.loc, ast.Var.Name(id.loc, id.value))

    elseif self:peek("(") then
        local open = self:e()
        local exp  = self:Exp()
        local _    = self:e(")", open)
        return ast.Exp.Paren(open.loc, exp)

    else
        local what = (is_statement and "a statement" or "an expression")
        self:unexpected_token_error(what)
    end
end

function Parser:SuffixedExp(is_statement)
    local exp = self:PrimaryExp(is_statement)
    while true do
        if self:peek(".") then
            local start = self:e()
            local id    = self:e("NAME")
            exp = ast.Exp.Var(start.loc, ast.Var.Dot(start.loc, exp, id.value))

        elseif self:peek("[") then
            local start = self:e()
            local index = self:Exp()
            local _     = self:e("]", start)
            exp = ast.Exp.Var(start.loc, ast.Var.Bracket(start.loc, exp, index))

        elseif self:peek(":") then
            local _    = self:e()
            local id   = self:e("NAME")
            local args = self:FuncArgs()
            exp = ast.Exp.CallMethod(exp.loc, exp, id.value, args)

        elseif self:peek("(") or self:peek("STRING") or self:peek("{") then
            local args = self:FuncArgs()
            exp = ast.Exp.CallFunc(exp.loc, exp, args)

        else
            return exp
        end
    end
end

function Parser:FuncArgs()
    if self:peek("STRING") or self:peek("{") then
        return { self:SimpleExp() }
    else
        local open = self:e("(")
        local exps = self:peek(")") and {} or self:ExpList1()
        local _    = self:e(")", open)
        return exps
    end
end

function Parser:SimpleExp()
    if     self:peek("NUMBER") then
        local id = self:e()
        if     math.type(id.value) == "integer" then return ast.Exp.Integer(id.loc, id.value)
        elseif math.type(id.value) == "float"   then return ast.Exp.Float(id.loc, id.value)
        else error("impossible") end

    elseif self:peek("STRING") then
        local tok = self:e()
        return ast.Exp.String(tok.loc, tok.value)

    elseif self:peek("nil") then
        local tok = self:e()
        return ast.Exp.Nil(tok.loc)

    elseif self:peek("true") then
        local tok = self:e()
        return ast.Exp.Bool(tok.loc, true)

    elseif self:peek("false") then
        local tok = self:e()
        return ast.Exp.Bool(tok.loc, false)

    elseif self:peek("...") then
        error("not implemented yet")

    elseif self:peek("{") then
        local open = self:e()
        local fields = {}
        repeat
            if self:peek("}") then break end
            table.insert(fields, self:Field())
        until not self:FieldSep()
        self:e("}", open)
        return ast.Exp.Initlist(open.loc, fields)

    else
        return self:SuffixedExp(false)
    end
end

function Parser:CastExp()
    local exp = self:SimpleExp()
    while self:peek("as") do
        local op  = self:e()
        local typ = self:Type()
        exp = ast.Exp.Cast(op.loc, exp, typ, self.next.loc)
    end
    return exp
end

local unary_ops_list = "not - ~ #"
local right_ops_list = "^ .."
local binops_list = {
    [14] = "^",
  --[13] = reserved for '^'
  --[12] = reserved for unary operators
    [11] = "* % / //",
    [10] = "+ -",
    [ 9] = "..",
  --[ 8] = reserved for '..'
    [ 7] = "<< >>",
    [ 6] = "&",
    [ 5] = "~",
    [ 4] = "|",
    [ 3] = "== ~= < > <= >=",
    [ 2] = "and",
    [ 1] = "or",
}

local is_unary_operator    = {} -- op => bool
local is_right_associative = {} -- op => bool
local binop_precedence = {} -- op => integer
local unary_precedence = 12

for op in unary_ops_list:gmatch("%S+") do
    is_unary_operator[op] = true
end
for op in right_ops_list:gmatch("%S+") do
    is_right_associative[op] = true
end
for prec, ops_str in pairs(binops_list) do
    for op in ops_str:gmatch("%S+") do
        binop_precedence[op] = prec
    end
end

-- subexpr -> (castexp | unop subexpr) { binop subexpr }
-- where 'binop' is any binary operator with a priority higher than 'limit'
function Parser:SubExp(limit)

    local exp
    if is_unary_operator[self.next.name] then
        local op   = self:e()
        local uexp = self:SubExp(unary_precedence)
        exp = ast.Exp.Unop(op.loc, op.name, uexp)
    else
        exp = self:CastExp()
    end

    while true do
        local prec = binop_precedence[self.next.name]
        if not prec or prec <= limit then
            break
        end

        local op   = self:e()
        local bexp = self:SubExp(is_right_associative[op.name] and prec-1 or prec)
        if op.name == ".." then
            if bexp._tag == "ast.Exp.Concat" then
                exp = ast.Exp.Concat(op.loc, {exp, table.unpack(bexp.exps) })
            else
                exp = ast.Exp.Concat(op.loc, {exp, bexp})
            end
        else
            exp = ast.Exp.Binop(op.loc, exp, op.name, bexp)
        end
    end

    return exp
end

function Parser:Exp()
    return self:SubExp(0)
end

function Parser:ExpList1()
    local exps = {}
    table.insert(exps, self:Exp())
    while self:try(",") do
        table.insert(exps, assert(self:Exp()))
    end
    return exps
end

--
-- Table fields
--

function Parser:Field()
    if self:peek("NAME") and self:doublepeek("=") then
        local id   = self:e("NAME")
        local _    = self:e("=")
        local exp  = self:Exp()
        return ast.Field.Rec(id.loc, id.value, exp)
    else
        local exp = self:Exp()
        return ast.Field.List(exp.loc, exp)
    end
end

function Parser:FieldSep()
    return self:try(",") or self:try(";")
end

--
-- Syntax errors
--


function Parser:describe_token_name(name)
    if     name == "EOF"    then return "end of the file"
    elseif name == "NUMBER" then return "number"
    elseif name == "STRING" then return "string"
    elseif name == "NAME"   then return "a name"
    else
        assert(not string.match(name, "^[A-Z]+$"))
        return string.format("'%s'", name)
    end
end

function Parser:describe_token(tok)
    if tok.name == "NAME" then
        return string.format("'%s'", tok.value)
    else
        return self:describe_token_name(tok.name)
    end
end

function Parser:syntax_error(loc, fmt, ...)
    coroutine.yield(loc:format_error(fmt, ...))
end

function Parser:forced_syntax_error(expected_name)
    self:e(expected_name)
    error("unreachable")
end

function Parser:unexpected_token_error(non_terminal)
    local where = self:describe_token(self.next)
    self:syntax_error(self.next.loc, "Unexpected %s while trying to parse %s", where, non_terminal)
end

function Parser:wrong_token_error(expected_name, open_tok)
    local loc   = self.next.loc
    local what  = self:describe_token_name(expected_name)
    local where = self:describe_token(self.next)
    if not open_tok or loc.line == open_tok.loc.line then
        self:syntax_error(loc, "Expected %s before %s", what, where)
    else
        local owhat = self:describe_token_name(open_tok.name)
        self:syntax_error(loc, "Expected %s before %s, to close the %s at line %d",
            what, where, owhat, open_tok.loc.line)
    end
end

--
-- Public interface
--

local parser = {}

function parser.parse(lexer)
    local co = coroutine.create(function()
        return Parser.new(lexer):Program()
    end)
    local ok, value = coroutine.resume(co)
    if ok then
        if coroutine.status(co) == "dead" then
            local prog_ast = value
            return prog_ast, {}
        else
            local compiler_error_msg = value
            return false, { compiler_error_msg }
        end
    else
        local unhandled_exception_msg = value
        local stack_trace = debug.traceback(co)
        error(unhandled_exception_msg .. "\n" .. stack_trace)
    end
end

return parser
