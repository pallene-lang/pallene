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
    self.prev = false -- Token
    self.next = false -- Token
    self.look = false -- Token
    self:advance(); self:advance()
    assert(self.next)
    assert(self.look)
end

function Parser:advance()
    local err
    self.prev = self.next
    self.next = self.look
    self.look, err = self.lexer:next()
    if not self.look then
        self:syntax_error(self.lexer:loc(), err)
    end
end

-- Check the next token without consuming it
function Parser:peek(name)
    assert(self.next.name)
    return (name == self.next.name)
end

-- Check the next-next token without consuming it
function Parser:doublepeek(name)
    assert(self.look.name)
    return (name == self.look.name)
end

-- Success: returns true, advances parser
-- Failure: returns false
function Parser:try(name)
    if self:peek(name) then
        self:advance()
        return true
    else
        return false
    end
end

-- [e]xpect one token.
-- If the optional open_name is provided, it means we are a closing token ({}, (), do end, etc).
function Parser:e(name, open_tok)
    if self:try(name) then
        return self.prev.value
    else
        if open_tok then
            self:missing_close_token_error(name, open_tok)
        else
            self:wrong_token_error(name)
        end
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
    if self:try("typealias") then
        local start_tok = self.prev
        local name = self:e("NAME")
        local _    = self:e("=")
        local typ  = self:Type()
        return ast.Toplevel.Typealias(start_tok.loc, name, typ, self.next.loc)

    elseif self:try("record") then
        local start_tok = self.prev
        local name   = self:e("NAME")
        local fields = {}
        while self:peek("NAME") do
            local decl = self:Decl()
            if not decl.type then self:e(":") end
            local _ = self:FieldSep()
            table.insert(fields, decl)
        end
        self:e("end", start_tok)
        return ast.Toplevel.Record(start_tok.loc, name, fields, self.next.loc)

    else
        local visibility_tok
        if self:try("local") or self:try("export") then
            visibility_tok = self.prev
        else
            visibility_tok = false
        end

        if self:try("function") then
            local start_tok = self.prev
            local name      = self:e("NAME")
            local _         = self:e("("); local paren_tok = self.prev
            local params    = self:DeclList()
            local _         = self:e(")", paren_tok)
            local rt_col_tok = self.next
            local ret_types = self:try(":") and self:RetTypes() or {}
            local rt_end_tok = self.next
            local block     = self:Block()
            local _         = self:e("end", start_tok)

            if not visibility_tok then
                self:syntax_error(start_tok.loc,
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
            local func_typ = ast.Type.Function(visibility_tok.loc, arg_types, ret_types)

            return ast.Toplevel.Func(
                visibility_tok.loc, visibility_tok.name,
                ast.Decl.Decl(visibility_tok.loc, name, false, func_typ, false),
                ast.Exp.Lambda(visibility_tok.loc, params, block),
                rt_col_tok.loc, rt_end_tok.loc)

        elseif self:peek("NAME") then
            local decls = self:DeclList(); assert(#decls > 0)
            local _     = self:e("=")
            local exps  = self:ExpList1();

            if not visibility_tok then
                self:syntax_error(decls[1].loc,
                    "Variable declarations must have a 'local' or 'export' modifier")
            end

            return ast.Toplevel.Var(visibility_tok.loc, visibility_tok.name, decls, exps)

        else
            if visibility_tok then
                self:e("NAME");
                error("unreachable")
            else
                self:unexpected_token_error("a toplevel declaration")
            end
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
    local _        = self:e("(");
    local open_tok = self.prev

    local ts = {}
    if not self:peek(")") then
        table.insert(ts, self:Type())
        while self:try(",") do
            table.insert(ts, self:Type())
        end
    end
    self:e(")", open_tok)

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
    if     self:try("nil")     then return ast.Type.Nil     (self.prev.loc)
    elseif self:try("boolean") then return ast.Type.Boolean (self.prev.loc)
    elseif self:try("integer") then return ast.Type.Integer (self.prev.loc)
    elseif self:try("float")   then return ast.Type.Float   (self.prev.loc)
    elseif self:try("string")  then return ast.Type.String  (self.prev.loc)
    elseif self:try("any")     then return ast.Type.Any     (self.prev.loc)
    elseif self:try("NAME")    then return ast.Type.Name    (self.prev.loc, self.prev.value)
    elseif self:try("{") then
        local open_tok = self.prev
        if self:peek("}") or (self:peek("NAME") and self:doublepeek(":")) then
            local fields = {}
            repeat
                if self:peek("}") then break end
                local name = self:e("NAME")
                local _    = self:e(":")
                local typ  = self:Type()
                table.insert(fields, { name = name, type = typ })
            until not self:FieldSep()
            self:e("}", open_tok)
            return ast.Type.Table(open_tok.loc, fields)

        else
            local typ = self:Type()
            local _ = self:e("}", open_tok)
            return ast.Type.Array(open_tok.loc, typ)
        end
    else
        self:unexpected_token_error("a type")
    end
end

--
-- Decls
--

function Parser:Decl()
    local name = self:e("NAME")
    local loc  = self.prev.loc
    if self:try(":") then
        local cloc = self.prev.loc
        local typ  = self:Type()
        return ast.Decl.Decl(loc, name, cloc, typ, self.next.loc)
    else
        return ast.Decl.Decl(loc, name, false, false, false)
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
    local start_tok = self.next
    local stats = {}
    while true do
        while self:try(";") do --[[skip empty statement]] end
        if self:block_follow() then break end
        local stat = self:Stat()
        local _    = self:try(";")
        table.insert(stats, stat)
        if stat._tag == "ast.Stat.Return" then
            break
        end
    end
    return ast.Stat.Block(start_tok.loc, stats)
end

function Parser:Stat()
    if self:try("do") then
        local start_tok = self.prev
        local body = self:Block()
        local _    = self:e("end", start_tok)
        return body

    elseif self:try("while") then
        local start_tok = self.prev
        local cond = self:Exp()
        local _    = self:e("do"); self:loop_begin()
        local body = self:Block()
        local _    = self:e("end", start_tok); self:loop_end()
        return ast.Stat.While(start_tok.loc, cond, body)

    elseif self:try("repeat") then
        local start_tok = self.prev
        self:loop_begin()
        local body = self:Block()
        local _    = self:e("until", start_tok); self:loop_end()
        local cond = self:Exp()
        return ast.Stat.Repeat(start_tok.loc, body, cond)

    elseif self:try("if") then
        local start_tok = self.prev
        local texp  = self:Exp()
        local _     = self:e("then")
        local tbody = self:Block()

        local eifs = {}
        while self:try("elseif") do
            local eiloc = self.prev.loc
            local eiexp  = self:Exp()
            local _      = self:e("then")
            local eibody = self:Block()
            table.insert(eifs, {eiloc, eiexp, eibody})
        end

        local ebody
        if self:try("else") then
            ebody = self:Block()
        else
            ebody = ast.Stat.Block(false, {})
        end

        self:e("end", start_tok)

        for i = #eifs, 1, -1 do
            local eif = eifs[i]
            ebody = ast.Stat.If(eif[1], eif[2], eif[3], ebody)
        end
        return ast.Stat.If(start_tok.loc, texp, tbody, ebody)

    elseif self:try("for") then
        local start_tok = self.prev
        local decl1  = self:Decl()

        if self:try("=") then
            local start = self:Exp()
            local _     = self:e(",")
            local limit = self:Exp()
            local step  = self:try(",") and self:Exp()
            local _     = self:e("do"); self:loop_begin()
            local body  = self:Block()
            local _     = self:e("end", start_tok); self:loop_end()
            return ast.Stat.For(start_tok.loc, decl1, start, limit, step, body)

        elseif self:peek(",") or self:peek("in") then
            local decls = {decl1}
            while self:try(",") do
                table.insert(decls, self:Decl())
            end
            local _    = self:e("in")
            local exps = self:ExpList1()
            local _    = self:e("do"); self:loop_begin()
            local body = self:Block()
            local _    = self:e("end", start_tok); self:loop_end()
            self:syntax_error(start_tok.loc, "for-in loops are not implemented yet")
            return ast.Stat.ForIn(start_tok.loc, decls, exps, body)

        else
            self:unexpected_token_error("a for loop")

        end

    elseif self:try("local") then
        local start_tok = self.prev
        local decls = self:DeclList()
        if #decls == 0 then self:e("NAME") end
        local exps  = self:try("=") and self:ExpList1() or {}
        return ast.Stat.Decl(start_tok.loc, decls, exps)

    elseif self:try("break") then
        if self.loop_depth > 0 then
            return ast.Stat.Break(self.prev.loc)
        else
            self:syntax_error(self.prev.loc, "break statement outside of a loop")
        end

    elseif self:try("return") then
        local start_tok = self.prev
        if self:peek(";") or self:block_follow() then
            return ast.Stat.Return(start_tok.loc, {})
        else
            return ast.Stat.Return(start_tok.loc, self:ExpList1())
        end

    else
        -- Assignment or function call
        local exp = self:SuffixedExp(true)
        if self:peek("=") or self:peek(",") then
            local lhs = { self:to_var(exp) }
            while self:try(",") do
                table.insert(lhs, self:to_var(self:SuffixedExp(false)))
            end
            local _ = self:e("=")
            local rhs = self:ExpList1()
            return ast.Stat.Assign(lhs[1].loc, lhs, rhs)

        else
            if exp._tag == "ast.Exp.CallFunc" or exp._tag == "ast.Exp.CallMethod" then
                return ast.Stat.Call(exp.loc, exp)
            else
                self:syntax_error_here("Expression is not a function call")
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
        self:syntax_error_here("This expression is not an lvalue")
    end
end

--
-- Expressions
--

function Parser:PrimaryExp(is_statement)
    if self:try("NAME") then
        return ast.Exp.Var(self.prev.loc, ast.Var.Name(self.prev.loc, self.prev.value))

    elseif self:try("(") then
        local start_tok = self.prev
        local exp = self:Exp()
        local _   = self:e(")", start_tok)
        return ast.Exp.Paren(start_tok.loc, exp)

    else
        if is_statement then
            self:unexpected_token_error("a statement")
        else
            self:unexpected_token_error("an expression")
        end
    end
end

function Parser:SuffixedExp(is_statement)
    local exp = self:PrimaryExp(is_statement)
    while true do
        if self:try(".") then
            local start_tok = self.prev
            local name = self:e("NAME")
            exp = ast.Exp.Var(start_tok.loc, ast.Var.Dot(start_tok.loc, exp, name))

        elseif self:try("[") then
            local start_tok = self.prev
            local iexp = self:Exp()
            local _    = self:e("]", start_tok)
            exp = ast.Exp.Var(start_tok.loc, ast.Var.Bracket(start_tok.loc, exp, iexp))

        elseif self:try(":") then
            local name = self:e("NAME")
            local args = self:FuncArgs()
            exp = ast.Exp.CallMethod(exp.loc, exp, name, args)

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
        local _ = self:e("("); local open_tok = self.prev
        local exps = self:peek(")") and {} or self:ExpList1()
        local _ = self:e(")", open_tok)
        return exps
    end
end

function Parser:SimpleExp()
    if     self:try("NUMBER") then
        local n   = self.prev.value
        if     math.type(n) == "integer" then return ast.Exp.Integer(self.prev.loc, n)
        elseif math.type(n) == "float"   then return ast.Exp.Float(self.prev.loc, n)
        else error("impossible") end

    elseif self:try("STRING") then return ast.Exp.String(self.prev.loc, self.prev.value)
    elseif self:try("nil")    then return ast.Exp.Nil(self.prev.loc)
    elseif self:try("true")   then return ast.Exp.Bool(self.prev.loc, true)
    elseif self:try("false")  then return ast.Exp.Bool(self.prev.loc, false)
    elseif self:try("...")    then error("not implemented yet")
    elseif self:try("{") then
        local open_tok = self.prev
        local fields = {}
        repeat
            if self:peek("}") then break end
            table.insert(fields, self:Field())
        until not self:FieldSep()
        self:e("}", open_tok)
        return ast.Exp.Initlist(open_tok.loc, fields)

    else
        return self:SuffixedExp(false)
    end
end

function Parser:CastExp()
    local exp = self:SimpleExp()
    while self:try("as") do
        local op_tok = self.prev
        local typ  = self:Type()
        exp = ast.Exp.Cast(op_tok.loc, exp, typ, self.next.loc)
    end
    return exp
end

local precedence_levels = {
    [14] = "^",
  --[13] = reserved for "^"
  --[12] = unary operators
    [11] = "* % / //",
    [10] = "+ -",
    [ 9] = "..",
  --[ 8] = reserved for ".."
    [ 7] = "<< >>",
    [ 6] = "&",
    [ 5] = "~",
    [ 4] = "|",
    [ 3] = "== ~= < > <= >=",
    [ 2] = "and",
    [ 1] = "or",
}
local unary_precedence = 12
local is_right_associative = {
    ["^"]  = true,
    [".."] = true,
}

local precedence  = {} -- op => integer
for n, opstr in pairs(precedence_levels) do
    for op in opstr:gmatch("%S+") do
        precedence[op] = n
    end
end

-- subexpr -> (castexp | unop subexpr) { binop subexpr }
-- where 'binop' is any binary operator with a priority higher than 'limit'
function Parser:SubExp(limit)

    local exp
    if self:try("not") or self:try("-") or self:try("~") or self:try("#") then
        local op   = self.prev
        local uexp = self:SubExp(unary_precedence)
        exp = ast.Exp.Unop(op.loc, op.name, uexp)
    else
        exp = self:CastExp()
    end

    while true do
        local op = self.next
        local prec = precedence[op.name]
        if not prec or prec <= limit then
            break
        end

        local _ = self:e(op.name)
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
        local start_tok = self.next
        local name = self:e("NAME")
        local _    = self:e("=")
        local exp  = self:Exp()
        return ast.Field.Rec(start_tok.loc, name, exp)
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
    coroutine.yield(loc:format_error(fmt, ...) .. ".")
end

function Parser:syntax_error_here(explanation)
    local where = self:describe_token(self.next)
    self:syntax_error(self.next.loc, "Syntax error before %s. %s", where, explanation)
end

function Parser:unexpected_token_error(non_terminal)
    local where = self:describe_token(self.next)
    self:syntax_error(self.next.loc, "Unexpected %s while trying to parse %s", where, non_terminal)
end

function Parser:wrong_token_error(expected_name)
    local what  = self:describe_token_name(expected_name)
    local where = self:describe_token(self.next)
    self:syntax_error(self.next.loc, "Expected %s before %s", what, where)
end

function Parser:missing_close_token_error(expected_name, open_tok)
    if self.next.loc.line == open_tok.loc.line then
        self:wrong_token_error(expected_name)
    else
        local what  = self:describe_token_name(expected_name)
        local owhat = self:describe_token_name(open_tok.name)
        local where = self:describe_token(self.next)
        self:syntax_error(self.next.loc,
            "Expected %s before %s, to close the %s at line %d",
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
