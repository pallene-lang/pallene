-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local ast = require "pallene.ast"
local util = require "pallene.util"
local trycatch = require "pallene.trycatch"

-- This module implements the Pallene parser. It is loosely based on the Lua parser from lparser.c,
-- including the error messages. We use an LL(2) grammar, which requires one extra token of
-- lookahead.

local Parser = util.Class()

-- The Lua VM might have a hard time calling functions with too many arguments.
-- Lua itself does not allow more than 200 upvalues, function parameters or local variables
-- since it uses 1-byte long unsigned numbers to store stack offsets for locals.
local MaxParams = 200

function Parser:init(lexer)
    self.lexer = lexer
    self.errors = {}  -- list of string
    self.prev = false -- Token
    self.next = false -- Token
    self.look = false -- Token

    -- Are we inside a loop? (for break statements)
    self.loop_depth = 0

    -- Info for the Lua backend
    self.region_depth = 0     -- Are we inside a type annotation?
    self.type_regions = {}    -- Sequence of pairs. Ranges of type annotations in program.
    self.comment_regions = {} -- Sequence of pairs. Ranges of comments in the program.

    -- Better error messages for missing "end" tokens (inspired by Luacheck and Rust)
    self.curr_line   = 0
    self.curr_indent = 0
    self.indent_of_token = {}    -- { token => integer }
    self.mismatched_indentation = {} -- list of tokens (2i+1 = open, 2i+2 = close)
    setmetatable(self.indent_of_token, { __mode = "k" })

    self:advance(); self:advance()
end

function Parser:advance()
    local tok, err
    repeat
        tok, err = self.lexer:next()
        if not tok then
            self:syntax_error(self.lexer:loc(), "%s", err)
        end
        if tok.name == "COMMENT" then
            table.insert(self.comment_regions, { tok.loc.pos, tok.end_pos })
        end
    until tok.name ~= "COMMENT"

    self.prev = self.next
    self.next = self.look
    self.look = tok

    if tok.loc.line > self.curr_line then
        self.curr_line   = tok.loc.line
        self.curr_indent = tok.loc.col
    end
    self.indent_of_token[tok] = self.curr_indent

    return self.prev
end

-- Check the next token without consuming it
function Parser:peek(name)
    local x = assert(self.next.name)
    return (name == x)
end

function Parser:peekSet(set)
    local x = assert(self.next.name)
    return (set[x] ~= nil)
end

-- Check the next-next token without consuming it
function Parser:doublepeek(name)
    local x = assert(self.look.name)
    return (name == x)
end

-- [E]xpect a token of a given type.
-- If the name is not provided, match whatever token we just peek-ed.
-- If the optional open_tok is provided then we are matching a closing token ({}, (), do end, etc).
function Parser:e(name, open_tok)
    local tok = self:try(name)
    if tok then
        if open_tok then
            -- Pay attention to suspicious indentation
            local d1 = assert(self.indent_of_token[open_tok])
            local d2 = assert(self.indent_of_token[tok])
            if d1 > d2 then
                table.insert(self.mismatched_indentation, open_tok)
                table.insert(self.mismatched_indentation, tok)
            end
        end
        return tok
    else
        self:wrong_token_error(name, open_tok)
    end
end

-- Optionally matches a token of a given type.
function Parser:try(name)
    assert(name)
    assert(name ~= "EOF")
    if self:peek(name) then
        return self:advance()
    else
        return false
    end
end

-- Call these methods around loop bodies.
-- This lets us detect if a break statement is used outside a loop.
function Parser:loop_begin()
    self.loop_depth = self.loop_depth + 1
end

function Parser:loop_end()
    self.loop_depth = self.loop_depth - 1
end

-- The region_begin() and region_end() methods are used to mark the regions which the Pallene to Lua
-- translator removes. The regions are packaged as part of the AST. The ranges of the regions are
-- inclusive.
function Parser:region_begin()
    if self.region_depth == 0 then
        local pos = (self.prev and self.prev.end_pos + 1 or 1)
        table.insert(self.type_regions, { pos, false })
    end
    self.region_depth = self.region_depth + 1
end

function Parser:region_end(skip_spaces)
    assert(self.region_depth > 0)
    self.region_depth = self.region_depth - 1
    if self.region_depth == 0 then
        local region = self.type_regions[#self.type_regions]
        if skip_spaces then
            region[2] = self.next.loc.pos - 1
        else
            region[2] = self.prev.end_pos
        end
    end
end

--
-- FIRST sets
--

local function Set(str)
    local t = {}
    for name in str:gmatch("%S+") do
        t[name] = true
    end
    return t
end

local function Union(sets)
    local t = {}
    for _, set in ipairs(sets) do
        for k, _ in pairs(set) do
            t[k] = true
        end
    end
    return t
end

local is_primary_exp_first = Set 'NAME ('
local is_simple_exp_first  = Set 'NUMBER STRING false function nil true ... {'
local is_type_first        = Set 'NAME nil ( {'
local is_stat_keyword      = Set 'break do for function if local repeat return while ;'
local is_toplevel_keyword  = Set 'record typealias'

local is_unary_operator    = Set 'not - ~ #'
local is_right_associative = Set '^ ..'

local unop_precedence = 12
local binop_precedence = {}
for prec, ops_str in pairs({
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
}) do
    for op in ops_str:gmatch("%S+") do
        binop_precedence[op] = prec
    end
end

local is_exp_first = Union({
    is_primary_exp_first,
    is_simple_exp_first,
    is_unary_operator,
})

local is_stat_first = Union({
    is_stat_keyword,
    is_primary_exp_first,
})

local is_toplevel_first = Union({
    is_toplevel_keyword,
    is_stat_first,
})

--
-- Toplevel
--

function Parser:Program()

    local start_loc = self.next.loc

    -- local <modname>: module = {}
    local modname = false
    if self:peek("local") and self:doublepeek("NAME") then
        local stat = self:Stat()
        assert(stat._tag == "ast.Stat.Decl")

        if #stat.decls > 1 or #stat.exps > 1 then
            self:syntax_error(stat.loc,
                "cannot use a multiple-assignment to declare the module table")
        else
            local decl = stat.decls[1]; assert(decl)
            local exp  = stat.exps[1]
            local ast_typ = decl.type

            if ast_typ and not (ast_typ._tag == "ast.Type.Name" and ast_typ.name == "module") then
                self:syntax_error(ast_typ.loc,
                    "if the module variable has a type annotation, it must be exactly 'module'")
            end

            if not (exp and exp._tag == "ast.Exp.InitList" and #exp.fields == 0) then
                self:syntax_error(stat.loc, "the module initializer must be exactly {}")
            end

            modname = decl.name
        end
    else
        self:syntax_error(start_loc,
            "must begin with a module declaration; local <modname> = {}")
    end

    -- module contents
    local tls = {}
    local return_stat = false
    while self:peekSet(is_toplevel_first) do

        local tl = self:Toplevel()
        table.insert(tls, tl)

        if tl._tag == "ast.Toplevel.Stats" then
            for _, stat in ipairs(tl.stats) do
                if stat._tag == "ast.Stat.Assign" then
                    for _, var in ipairs(stat.vars) do
                        if var._tag ~= "ast.Var.Dot" then
                            self:syntax_error(var.loc,
                                "toplevel assignments are only possible with module fields")
                        end
                    end
                end
            end

            local last = tl.stats[#tl.stats]
            if last and last._tag == "ast.Stat.Return" then
                return_stat = table.remove(tl.stats)
                break
            end
        end
    end

    -- return <modname>
    if return_stat then
        if #return_stat.exps ~= 1 then
            self:syntax_error(return_stat.loc,
                "the module return statement must return a single value")
        else
            local exp = return_stat.exps[1]
            if modname and not (
                exp._tag == "ast.Exp.Var" and
                exp.var._tag == "ast.Var.Name" and
                exp.var.name == modname)
            then
                -- The checker also needs to check that this name has not been shadowed
                self:syntax_error(exp.loc,
                    "must return exactly the module variable '%s'", modname)
            end
        end

        if not self:peek("EOF") then
            self:syntax_error(self.next.loc,
                "the module return statement must be the last thing in the file")
        end
    else
        if self:peek("EOF") then
            local loc = self.next.loc
            local what = (modname or "<modname>")
            self:syntax_error(loc,  "must end by returning the module table; return %s", what)
        else
            self:unexpected_token_error("a toplevel element")
        end
    end

    local end_loc = self.next.loc
    return ast.Program.Program(
        start_loc, end_loc, modname, tls, self.type_regions, self.comment_regions)
end

local is_allowed_toplevel = Set [[
    ast.Stat.Decl
    ast.Stat.Assign
    ast.Stat.Functions
    ast.Stat.Return
]]

function Parser:Toplevel()
    if self:peek("typealias") then
        self:region_begin()
        local start = self:advance()
        local id    = self:e("NAME")
        local _     = self:e("=")
        local typ   = self:Type()
        self:region_end()
        return ast.Toplevel.Typealias(start.loc, id.value, typ)

    elseif self:peek("record") then
        self:region_begin()
        local start  = self:advance()
        local id     = self:e("NAME")
        local fields = {}
        while self:peek("NAME") do
            local decl = self:Decl()
            if not decl.type then self:forced_syntax_error(":") end
            self:try(";")
            table.insert(fields, decl)
        end
        self:e("end", start)
        self:region_end()
        return ast.Toplevel.Record(start.loc, id.value, fields)

    else
        local stats = self:StatList()

        for _, stat in ipairs(stats) do
            if not is_allowed_toplevel[stat._tag] then
                self:syntax_error(stat.loc,
                    "toplevel statements can only be Returns, Declarations or Assignments")
            end
        end

        local loc = stats[1] and stats[1].loc
        return ast.Toplevel.Stats(loc, stats)
    end
end

--
-- Types
--

function Parser:Type()
    if self:peek("(") then
        local loc = self.next.loc
        local aa  = self:TypeList()
        local _   = self:e("->")
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

function Parser:TypeList()
    local ts = {}
    local open = self:e("(")
    if self:peekSet(is_type_first) then
        table.insert(ts, self:Type())
        while self:try(",") do
            table.insert(ts, self:Type())
        end
    end
    self:e(")", open)
    return ts
end

function Parser:SimpleType()
    if self:peek("nil") then
        local tok = self:advance()
        return ast.Type.Nil(tok.loc)

    elseif self:peek("NAME") then
        local tok = self:advance()
        return ast.Type.Name(tok.loc, tok.value)

    elseif self:peek("{") then
        local open = self:advance()
        if self:peek("}") or (self:peek("NAME") and self:doublepeek(":")) then
            local fields = {}
            while self:peek("NAME") do
                local id  = self:e("NAME")
                local _   = self:e(":")
                local typ = self:Type()
                table.insert(fields, { name = id.value, type = typ })
                if not self:tryFieldSep() then
                    break
                end
            end
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
        self:region_begin()
        local _ = self:advance()
        local typ   = self:Type()
        self:region_end()
        return ast.Decl.Decl(id.loc, id.value, typ)
    else
        return ast.Decl.Decl(id.loc, id.value, false)
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

---
-- Mutualy Recursive Functions
-- ---------------------------
--
-- We allow Pallene functions to call other functions that are defined later down down the file.
-- However, we must ensure that we only call functions after they are initialized.
--
--   function m.f() return m.g() end
--   local _ = m.f() -- Bad! Calls m.g before it exists
--   function m.g() end
--
-- To disallow this sort of misbehaving program, we only allow functions to see downstream functions
-- that are "adjacent". If there is an intervening statement between the functions, the latter
-- function won't be in the scope for the first one.
--
--   function m.f() return m.g() end
--   function m.g() end
--   local _ = m.f() -- OK!
--
-- For local (non-exported) functions, we recognize the following idiom:
--
--   local f, g
--   function f() end
--   function g() end

local function is_forward_function_declaration(stats, i)
    local first = stats[i]
    if not (first and first._tag == "ast.Stat.Decl") then return false end
    if #first.exps > 0 then return false end

    local funcs_stat = stats[i+1]
    if not (funcs_stat and funcs_stat._tag == "ast.Stat.Functions") then return false end
    if next(funcs_stat.declared_names) then return false end

    return true
end

function Parser:find_letrecs(stats)
    local out = {}

    local N = #stats
    local i = 1
    while i <= N do

        local loc = stats[i].loc

        local forw_decls
        if is_forward_function_declaration(stats, i) then
            forw_decls = stats[i].decls
            i = i + 1
        else
            forw_decls = {}
        end

        local funcs = {}
        while i <= N do
            local stat = stats[i]
            if not (stat and stat._tag == "ast.Stat.Functions") then break end
            if next(stat.declared_names) then break end
            for _, func in ipairs(stat.funcs) do
                table.insert(funcs, func)
            end
            i = i + 1
        end

        if funcs[1] then
            -- Function group, possibly with forward-declared local functions
            local declared_names = {}
            for _, decl in ipairs(forw_decls) do
                if decl.type then
                    self:syntax_error(decl.loc,
                        "type annotations are not allowed in a function forward declaration")
                end
                if declared_names[decl.name] then
                    self:syntax_error(decl.loc,
                        "duplicate forward declaration for '%s'", decl.name)
                end
                declared_names[decl.name] = true
            end

            local defined_names = {}
            for _, func in ipairs(funcs) do
                if not func.module then
                    if not declared_names[func.name] then
                        self:syntax_error(func.loc,
                            "function '%s' was not forward declared", func.name)
                    end
                    defined_names[func.name] = true
                end
            end

            for _, decl in ipairs(forw_decls) do
                if not defined_names[decl.name] then
                    self:syntax_error(decl.loc,
                        "missing a function definition for '%s'", decl.name)
                end
            end

            table.insert(out, ast.Stat.Functions(loc, declared_names, funcs))

        else
            -- Other statements
            table.insert(out, stats[i])
            i = i + 1
        end
    end

    return out
end

--
-- Statements
--

function Parser:StatList()
    local list = {}
    while true do
        while self:try(";") do end
        if not self:peekSet(is_stat_first) then break end
        local stat = self:Stat()
        table.insert(list, stat)
        if stat._tag == "ast.Stat.Return" then break end
    end
    return self:find_letrecs(list)
end

function Parser:Block()
    assert(self.prev) -- typically a "do", "then", etc
    return ast.Stat.Block(self.prev.loc, self:StatList())
end

function Parser:FuncStat()
    local start = self:e("function")

    local root = self:e("NAME").value

    local fields = {}
    while self:try(".") do
        table.insert(fields, self:e("NAME").value)
    end

    if fields[2] then
        self:syntax_error(self.prev.loc,
            "more than one dot in the function name is not allowed")
    end

    local field = fields[1] or false

    local method = false
    if self:try(":") then
        method = self:e("NAME").value
    end

    local module, name
    if field then
        module = root
        name   = field
    else
        module = false
        name   = root
    end

    local params = self:FuncParams()

    local return_types = {}
    if self:peek(":") then
        self:region_begin()
        self:advance()
        return_types = self:RetTypes()
        self:region_end()
    end

    local block = self:FuncBody()
    local _     = self:e("end", start)

    for _, decl in ipairs(params) do
      if not decl.type then
        self:syntax_error(decl.loc,
          "parameter '%s' is missing a type annotation", decl.name)
      end
    end

    return ast.FuncStat.FuncStat(
        start.loc, module, name, method, return_types,
        ast.Exp.Lambda(start.loc, params, block))
end

function Parser:Stat()
    if self:peek("do") then
        local start = self:advance()
        local body  = self:Block()
        local _     = self:e("end", start)
        return body

    elseif self:peek("while") then
        local start = self:advance()
        local cond  = self:Exp()
        local _     = self:e("do"); self:loop_begin()
        local body  = self:Block(); self:loop_end()
        local _     = self:e("end", start)
        return ast.Stat.While(start.loc, cond, body)

    elseif self:peek("repeat") then
        local start = self:advance();     self:loop_begin()
        local body  = self:Block(); self:loop_end()
        local _     = self:e("until", start);
        local cond  = self:Exp()
        return ast.Stat.Repeat(start.loc, body, cond)

    elseif self:peek("if") then
        local if_start = self:advance()
        local if_exp   = self:Exp()
        local _        = self:e("then")
        local if_body  = self:Block()

        local eifs = {}
        while self:peek("elseif") do
            local ei_start = self:advance()
            local ei_exp   = self:Exp()
            local _        = self:e("then")
            local ei_body  = self:Block()
            table.insert(eifs, {ei_start.loc, ei_exp, ei_body})
        end

        local e_body
        if self:try("else") then
            e_body = self:Block()
        else
            e_body = ast.Stat.Block(self.next.loc, {})
        end

        self:e("end", if_start)

        for i = #eifs, 1, -1 do
            local eif = eifs[i]
            e_body = ast.Stat.If(eif[1], eif[2], eif[3], e_body)
        end
        return ast.Stat.If(if_start.loc, if_exp, if_body, e_body)

    elseif self:peek("for") then
        local start = self:advance()
        local decl1 = self:Decl()

        if self:try("=") then
            local init  = self:Exp()
            local _     = self:e(",")
            local limit = self:Exp()
            local step  = self:try(",") and self:Exp()
            local _     = self:e("do"); self:loop_begin()
            local body  = self:Block(); self:loop_end()
            local _     = self:e("end", start)
            return ast.Stat.ForNum(start.loc, decl1, init, limit, step, body)

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
            return ast.Stat.ForIn(start.loc, decls, exps, body)

        else
            self:unexpected_token_error("a for loop")

        end

    elseif self:peek("local") then
        local start = self:advance()
        if self:peek("function") then
            local fn = self:FuncStat()
            if fn.module then
                self:syntax_error(fn.loc, "local function name has a '.'")
            end
            if fn.method then
                self:syntax_error(start.loc, "local function name has a ':'")
            end
            return ast.Stat.Functions(start.loc, {[fn.name]=true}, {fn})
        else
            local decls = self:DeclList(); if #decls == 0 then self:forced_syntax_error("NAME") end
            local exps  = self:try("=") and self:ExpList1() or {}
            return ast.Stat.Decl(start.loc, decls, exps)
        end

    elseif self:peek("break") then
        local start = self:advance()
        if self.loop_depth == 0 then
            self:syntax_error(start.loc, "break statement outside of a loop")
        end
        return ast.Stat.Break(start.loc)

    elseif self:peek("return") then
        local start = self:advance()
        local exps  = self:ExpList0()
        self:try(";") -- Lua allows a single semicolon here
        return ast.Stat.Return(start.loc, exps)

    elseif self:peek("function") then
        local fn = self:FuncStat()
        return ast.Stat.Functions(fn.loc, {}, {fn})

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
                    "this expression in a statement position is not a function call")
                self:abort_parsing()
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
        self:syntax_error(exp.loc, "this expression is not an lvalue")
        self:abort_parsing()
    end
end

--
-- Expressions
--

function Parser:PrimaryExp(is_statement)
    if self:peek("NAME") then
        local id = self:advance()
        return ast.Exp.Var(id.loc, ast.Var.Name(id.loc, id.value))

    elseif self:peek("(") then
        local open = self:advance()
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
            local start = self:advance()
            local id    = self:e("NAME")
            exp = ast.Exp.Var(start.loc, ast.Var.Dot(start.loc, exp, id.value))

        elseif self:peek("[") then
            local start = self:advance()
            local index = self:Exp()
            local _     = self:e("]", start)
            exp = ast.Exp.Var(start.loc, ast.Var.Bracket(start.loc, exp, index))

        elseif self:peek(":") then
            local _    = self:advance()
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
        if #exps > MaxParams then
            self:syntax_error(exps[MaxParams + 1].loc,
                "too many arguments (limit is %d)", MaxParams)
        end
        return exps
    end
end

function Parser:FuncParams()
    local oparen = self:e("(")
    local params = self:DeclList()
    if #params > MaxParams then
        self:syntax_error(params[MaxParams + 1].loc,
            "too many parameters (limit is %d)", MaxParams)
    end
    local _ = self:e(")", oparen)
    return params
end

function Parser:FuncExp()
    local start  = self:e("function")
    local params = self:FuncParams(true)

    for _, decl in ipairs(params) do
        if decl.type then
            self:syntax_error(decl.loc, "Function expressions cannot be type annotated")
        end
    end

    if self:try(":") then
        local typ = self:Type()
        self:syntax_error(typ.loc, "Function expressions cannot be type annotated")
    end

    local block = self:FuncBody()
    local _     = self:e("end", start)

    return ast.Exp.Lambda(start.loc, params, block)
end

function Parser:FuncBody()
    local outer_loop_depth = self.loop_depth
    self.loop_depth = 0

    local block = self:Block()

    self.loop_depth = outer_loop_depth
    return block
end

function Parser:SimpleExp()
    if     self:peek("NUMBER") then
        local id = self:advance()
        if     math.type(id.value) == "integer" then return ast.Exp.Integer(id.loc, id.value)
        elseif math.type(id.value) == "float"   then return ast.Exp.Float(id.loc, id.value)
        else error("impossible") end

    elseif self:peek("STRING") then
        local tok = self:advance()
        return ast.Exp.String(tok.loc, tok.value)

    elseif self:peek("nil") then
        local tok = self:advance()
        return ast.Exp.Nil(tok.loc)

    elseif self:peek("true") then
        local tok = self:advance()
        return ast.Exp.Bool(tok.loc, true)

    elseif self:peek("false") then
        local tok = self:advance()
        return ast.Exp.Bool(tok.loc, false)

    elseif self:peek("...") then
        error("not implemented yet")

    elseif self:peek("{") then
        local open = self:advance()
        local fields = {}
        while self:peekSet(is_exp_first) do
            table.insert(fields, self:Field())
            if not self:tryFieldSep() then
                break
            end
        end
        self:e("}", open)
        return ast.Exp.InitList(open.loc, fields)

    elseif self:peek("function") then
        return self:FuncExp()
    else
        return self:SuffixedExp(false)
    end
end

function Parser:CastExp()
    local exp = self:SimpleExp()
    while self:peek("as") do
        self:region_begin()
        local op = self:advance()
        local typ = self:Type()
        self:region_end()
        exp = ast.Exp.Cast(op.loc, exp, typ)
    end
    return exp
end

-- subexpr -> (castexp | unop subexpr) { binop subexpr }
-- where 'binop' is any binary operator with a priority higher than 'limit'
function Parser:SubExp(limit)
    local exp
    if is_unary_operator[self.next.name] then
        local op   = self:advance()
        local uexp = self:SubExp(unop_precedence)
        exp = ast.Exp.Unop(op.loc, op.name, uexp)
    else
        exp = self:CastExp()
    end

    while true do
        local prec = binop_precedence[self.next.name]
        if not prec or prec <= limit then
            break
        end

        local op   = self:advance()
        local bexp = self:SubExp(is_right_associative[op.name] and prec-1 or prec)
        exp = ast.Exp.Binop(op.loc, exp, op.name, bexp)
    end

    return exp
end

function Parser:Exp()
    return self:SubExp(0)
end

function Parser:ExpList0()
    if self:peekSet(is_exp_first) then
        return self:ExpList1()
    else
        return {}
    end
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

function Parser:tryFieldSep()
    return self:try(",") or self:try(";")
end

--
-- Syntax errors
--
-- For simple errors that we have a good idea how to recover from them, we report a syntax error and
-- continue parsing. However, if we aren't immediately sure how to recover, we abort. We would
-- rather stop early than potentially create a bunch of spurious errors.

function Parser:syntax_error(loc, fmt, ...)
    local msg = "syntax error: " .. loc:format_error(fmt, ...)
    table.insert(self.errors, msg)
end

function Parser:abort_parsing()
    trycatch.error("syntax-error")
end

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

function Parser:forced_syntax_error(expected_name)
    self:e(expected_name)
    self:abort_parsing()
end

function Parser:unexpected_token_error(non_terminal)
    local where = self:describe_token(self.next)
    self:syntax_error(self.next.loc, "unexpected %s while trying to parse %s", where, non_terminal)
    self:abort_parsing()
end

function Parser:wrong_token_error(expected_name, open_tok)

    local next_tok = self.next
    local is_stolen_delimiter = false

    if open_tok then
        for i = 1, #self.mismatched_indentation, 2 do
            local susp_open  = self.mismatched_indentation[i]
            local susp_close = self.mismatched_indentation[i+1]
            if expected_name == susp_close.name and susp_open.loc.pos > open_tok.loc.pos then
                open_tok = susp_open
                next_tok = susp_close
                is_stolen_delimiter = true
                break
            end
        end
    end

    local loc = next_tok.loc
    local what  = self:describe_token_name(expected_name)
    local where = self:describe_token(next_tok)

    if not open_tok or loc.line == open_tok.loc.line then
        self:syntax_error(loc, "expected %s before %s", what, where)
    else
        local owhat = self:describe_token_name(open_tok.name)
        local oline = open_tok.loc.line
        if is_stolen_delimiter then
            self:syntax_error(loc,
                "expected %s to close %s at line %d, before this less indented %s",
                what, owhat, oline, what)
        else
            self:syntax_error(loc,
                "expected %s before %s, to close the %s at line %d",
                what, where, owhat, oline)
        end
    end

    self:abort_parsing()
end

--
-- Public interface
--

local parser = {}

function parser.parse(lexer)

    local p = Parser.new(lexer)

    local ok, ret = trycatch.pcall(function()
        return p:Program()
    end)

    -- Re-throw internal errors
    if not ok and ret.tag ~= "syntax-error" then
        error(ret)
    end

    if p.errors[1] then
        -- Had syntax errors
        return false, p.errors
    else
        -- No syntax errors
        assert(ok)
        local prog_ast = ret
        return prog_ast, {}
    end
end

return parser
