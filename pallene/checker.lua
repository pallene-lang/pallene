-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local ast = require "pallene.ast"
local builtins = require "pallene.builtins"
local symtab = require "pallene.symtab"
local types = require "pallene.types"
local typedecl = require "pallene.typedecl"
local util = require "pallene.util"

--
-- WHAT THE TYPE CHECKER DOES
-- ==========================
--
-- This compiler pass checks if the types are correct and resolves the scope of all identifiers.
-- It produces a modified AST that is annotated with the following information:
--
--   * _type: A types.T in the following kinds of nodes
--      - ast.Exp
--      - ast.Var
--      - ast.Decl
--      - ast.Toplevel.Record
--      - ast.Stat.Func
--
--   * _def: A checker.Def that describes the meaninge
--      - ast.Var.Name
--
--   * _is_exported: A boolean (true) marking assignments that are declaring an exported variable
--      - ast.Var.Name
--
--   * _skip: A boolean (true) marking nodes that should be skipped by the to_ir
--      - ast.Stat.Decl (the `local m:module={}` statement and the forward-decl for functions)
--      - ast.Stat.Return (the `return m` statement)
--
--   * _declared (used internally by the type checker)
--      - ast.Stat.Func
--
-- We also make some adjustments to the AST:
--
--   * We flatten qualified names such as `io.write` from ast.Var.Dot to ast.Var.Name.
--   * We insert explicit ast.Exp.Cast nodes where there is an implicit upcast or downcast.
--   * We insert ast.Exp.ExtraRet nodes to represent additional return values from functions.
--   * We insert an explicit call to tofloat in some arithmetic operations. For example int + float.
--   * We add an explicit +1 or +1.0 step in numeric for loops without a loop step.
--
-- For these transformations to work you should always use the return value from the check_exp and
-- check_var functions. For example, instead of just `check_exp(foo.exp)` you should always write
-- `foo.exp = check_exp(foo.exp)`.
--

local checker = {}

local Checker = util.Class()

-- Type-check a Pallene module
-- On success, returns the typechecked module for the program
-- On failure, returns false and a list of compilation errors
function checker.check(prog_ast)
    local co = coroutine.create(function()
        return Checker.new():check_program(prog_ast)
    end)
    local ok, value = coroutine.resume(co)
    if ok then
        if coroutine.status(co) == "dead" then
            prog_ast = value
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

-- We use coroutines.yield to raise an exception if we encounter a type error in the user program.
-- Some other things we tried that did not work:
-- 1) Produce a dummy "Void" type on errors, and keep going to produce more errors; too finnicky.
-- 2) Use "error" to raise the exception; I couldn't implement the required "try-catch".
local function checker_error(loc, fmt, ...)
    local error_message = loc:format_error(fmt, ...)
    coroutine.yield(error_message)
end

local function scope_error(loc, fmt, ...)
    return checker_error(loc, ("scope error: " .. fmt), ...)
end

local function type_error(loc, fmt, ...)
    return checker_error(loc, ("type error: " .. fmt), ...)
end

local function multiple_definitions_error(loc, name)
    assert(loc)
    scope_error(loc, "multiple definitions for module field '%s'", name)
end

local function check_type_is_condition(exp, fmt, ...)
    local typ = exp._type
    if typ._tag ~= "types.T.Boolean" and typ._tag ~= "types.T.Any" then
        type_error(exp.loc,
            "expression passed to %s has type %s. Expected boolean or any.",
            string.format(fmt, ...),
            types.tostring(typ))
    end
end

--
--
--

function Checker:init()
    self.module_symbol = false       -- checker.Symbol.Module
    self.module_var_name = false     -- string
    self.symbol_table = symtab.new() -- string => checker.Symbol
    self.ret_types_stack = {}        -- stack of types.T
    return self
end


--
-- Symbol table
--

local function declare_type(type_name, cons)
    typedecl.declare(checker, "checker", type_name, cons)
end

--
-- Type information, meant for for the type checker
-- For each name in scope, the type checker wants to know if it is a value and what is its type.
--
declare_type("Symbol", {
    Type   = { "typ"  },
    Value  = { "typ", "def" },
    Module = { "typ", "symbols" }, -- Note: a module name can also be a type (e.g. "string")
})

--
-- Provenance information, meant for the code generator
-- For each name in the AST, we to add an annotation to tell the codegen where it comes from.
--
declare_type("Def", {
    Variable = { "decl" },
    Function = { "stat" },
    Builtin  = { "id"   },
--  Import   = { ??? },
})

function Checker:add_type_symbol(name, typ)
    assert(type(name) == "string")
    assert(typedecl.match_tag(typ._tag, "types.T"))
    return self.symbol_table:add_symbol(name, checker.Symbol.Type(typ))
end

function Checker:add_value_symbol(name, typ, def)
    assert(type(name) == "string")
    assert(typedecl.match_tag(typ._tag, "types.T"))
    return self.symbol_table:add_symbol(name, checker.Symbol.Value(typ, def))
end

function Checker:add_module_symbol(name, typ, symbols)
    assert(type(name) == "string")
    assert((not typ) or typedecl.match_tag(typ._tag, "types.T"))
    return self.symbol_table:add_symbol(name, checker.Symbol.Module(typ, symbols))
end

--
--

function Checker:from_ast_type(ast_typ)
    local tag = ast_typ._tag
    if     tag == "ast.Type.Nil" then
        return types.T.Nil()

    elseif tag == "ast.Type.Name" then
        local name = ast_typ.name

        local sym = self.symbol_table:find_symbol(name)
        if not sym then
            scope_error(ast_typ.loc,  "type '%s' is not declared", name)
        end

        local stag = sym._tag
        if     stag == "checker.Symbol.Type" then
            return sym.typ
        elseif stag == "checker.Symbol.Module" then
            if sym.typ then
                return sym.typ
            else
                type_error(ast_typ.loc, "module '%s' is not a type", name)
            end
        elseif stag == "checker.Symbol.Value" then
            type_error(ast_typ.loc, "'%s' is not a type", name)
        else
            typedecl.tag_error(stag)
        end

    elseif tag == "ast.Type.Array" then
        local subtype = self:from_ast_type(ast_typ.subtype)
        return types.T.Array(subtype)

    elseif tag == "ast.Type.Table" then
        local fields = {}
        for _, field in ipairs(ast_typ.fields) do
            if fields[field.name] then
                type_error(ast_typ.loc, "duplicate field '%s' in table", field.name)
            end
            fields[field.name] = self:from_ast_type(field.type)
        end
        return types.T.Table(fields)

    elseif tag == "ast.Type.Function" then
        local p_types = {}
        for _, p_type in ipairs(ast_typ.arg_types) do
            table.insert(p_types, self:from_ast_type(p_type))
        end
        local ret_types = {}
        for _, ret_type in ipairs(ast_typ.ret_types) do
            table.insert(ret_types, self:from_ast_type(ret_type))
        end
        return types.T.Function(p_types, ret_types)

    else
        typedecl.tag_error(tag)
    end
end

function Checker:check_program(prog_ast)
    assert(prog_ast._tag == "ast.Program.Program")

    -- Add primitive types to the symbol table
    self:add_type_symbol("any",     types.T.Any())
    self:add_type_symbol("boolean", types.T.Boolean())
    self:add_type_symbol("float",   types.T.Float())
    self:add_type_symbol("integer", types.T.Integer())
    self:add_type_symbol("string",  types.T.String())

    -- Add builtins to symbol table.
    -- The order does not matter because they are distinct.
    for name, typ in pairs(builtins.functions) do
        self:add_value_symbol(name, typ, checker.Def.Builtin(name))
    end

    for mod_name, funs in pairs(builtins.modules) do
        local symbols = {}
        for fun_name, typ in pairs(funs) do
            local id = mod_name .. "." .. fun_name
            symbols[fun_name] = checker.Symbol.Value(typ, checker.Def.Builtin(id))
        end
        local typ = (mod_name == "string") and types.T.String() or false
        self:add_module_symbol(mod_name, typ, symbols)
    end

    -- Check toplevel
    for _, tl_node in ipairs(prog_ast.tls) do
        local tag = tl_node._tag
        if     tag == "ast.Toplevel.Stats" then
            self:check_stat_list(tl_node.stats, true)

        elseif tag == "ast.Toplevel.Typealias" then
            self:add_type_symbol(tl_node.name, self:from_ast_type(tl_node.type))

        elseif tag == "ast.Toplevel.Record" then
            local field_names = {}
            local field_types = {}
            for _, field_decl in ipairs(tl_node.field_decls) do
                local field_name = field_decl.name
                table.insert(field_names, field_name)
                field_types[field_name] = self:from_ast_type(field_decl.type)
            end

            local typ = types.T.Record(tl_node.name, field_names, field_types)
            self:add_type_symbol(tl_node.name, typ)

            tl_node._type = typ

        else
            typedecl.tag_error(tag)
        end
    end

    local total_nodes = #prog_ast.tls
    if total_nodes == 0 then
        type_error(prog_ast.loc, "Empty modules are not permitted")
    end

    if not self.module_symbol then
        type_error(prog_ast.loc, "Program has no module variable")
    end

    -- TODO: Does this protect against "do return end"?
    for i, tl in ipairs(prog_ast.tls) do
        if tl._tag == "ast.Toplevel.Stats" then
            for j, stat in ipairs(tl.stats) do
                if stat._tag == "ast.Stat.Return" and (i < #prog_ast.tls or j < #tl.stats) then
                    type_error(stat.loc, "Only the last toplevel node can be a return statement")
                end
            end
        end
    end

    local last_tl = prog_ast.tls[total_nodes]
    if last_tl._tag ~= "ast.Toplevel.Stats" or
       last_tl.stats[#last_tl.stats]._tag ~= "ast.Stat.Return" then
        local loc = last_tl.stats[#last_tl.stats].loc
        type_error(loc, "Last Toplevel element must be a return statement")
    end

    return prog_ast
end

-- If the last expression in @rhs is a function call that returns multiple values, add ExtraRet
-- nodes to the end of the list.
function Checker:expand_function_returns(rhs)
    local last = rhs[#rhs]
    if  last and (last._tag == "ast.Exp.CallFunc" or last._tag == "ast.Exp.CallMethod") then
        last = self:check_exp_synthesize(last)
        rhs[#rhs] = last
        for i = 2, #last._types do
            table.insert(rhs, ast.Exp.ExtraRet(last.loc, last, i))
        end
    end
end

function Checker:is_a_module_declaration(decls)
    for _, decl in ipairs(decls) do
        assert(decl._tag == "ast.Decl.Decl")
        if
            decl.type and
            decl.type._tag == "ast.Type.Name" and
            decl.type.name == "module" and
            not self.symbol_table:find_symbol("module")
        then
            return true
        end
    end
    return false
end

function Checker:is_the_module_variable(exp)
    -- Check if the expression is the module variable without calling check_exp.
    -- Doing that would have raised an exception because it is not a value.
    return (
        exp._tag == "ast.Exp.Var" and
        exp.var._tag == "ast.Var.Name" and
        (self.module_symbol == self.symbol_table:find_symbol(exp.var.name)))
end

-- Mutualy Recursive Functions
-- ===========================
--
-- We allow Pallene functions to call functions that are defined later down down the file. However,
-- we must ensure that we only call functions after they are initialized.
--
--   function m.f() return m.g() end
--   local _ = m.f() -- Bad! Cals m.g before it exists
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
-- For local (non-exported) funtions, we recognize the following idiom:
--
--   local f, g
--   function f() end
--   function g() end

function Checker:add_func_stat_to_scope(stat, is_toplevel)
    assert(stat._tag == "ast.Stat.Func")
    assert(not stat._declared)

    local arg_types = {}
    for i, decl in ipairs(stat.value.arg_decls) do
        arg_types[i] = self:from_ast_type(decl.type)
    end

    local ret_types = {}
    for i, ast_typ in ipairs(stat.ret_types) do
        ret_types[i] = self:from_ast_type(ast_typ)
    end

    local typ = types.T.Function(arg_types, ret_types)

    if stat.is_local then
        -- Local function
        assert(#stat.fields == 0)
        assert(not stat.method)
        self:add_value_symbol(stat.root, typ, checker.Def.Function(stat))
    else
        assert(not stat.method) -- not yet implemented
        if #stat.fields == 0 then
            -- Local function (forward declared)
            self:add_value_symbol(stat.root, typ, checker.Def.Function(stat))
        else
            -- Module function
            local sym = self.symbol_table:find_symbol(stat.root)
            if not sym then
                scope_error(stat.loc, "module '%s' is not declared", stat.root)
            end
            if sym._tag ~= "checker.Symbol.Module" then
                type_error(stat.loc, "'%s' is not a module", stat.root)
            end
            if not is_toplevel then
                scope_error(stat.loc, "module functions can only be set at the toplevel")
            end
            if sym ~= self.module_symbol then
                type_error(stat.loc, "attempting to reassign a function from external module") --TODO
            end
            if #stat.fields > 1 then
                type_error(stat.loc, "more than one dot in the function name is not allowed") --TODO
            end

            local name = stat.fields[1]
            if sym.symbols[name] then
                multiple_definitions_error(stat.loc, name)
            end
            sym.symbols[name] = checker.Symbol.Value(typ, checker.Def.Function(stat))
        end
    end

    stat._declared = true
    stat._type = typ
end

--
-- Does this statement look like it is the start of a forward declaration for a group of functions?
-- If yes, return a table with the set of names
--
local function is_forward_decl(stats, i)
    local stat = stats[i]
    if stat._tag ~= "ast.Stat.Decl" then return false end
    if #stat.exps > 0 then return false end

    local names = {}
    for _, decl in ipairs(stat.decls) do
        names[decl.name] = true
    end

    local fstat = stats[i+1]
    if not fstat then return false end
    if fstat._tag ~= "ast.Stat.Func" then return false end
    if fstat.is_local then return false end
    if #fstat.fields > 0 or fstat.method then return false end
    if not names[fstat.root] then return false end

    for _, decl in ipairs(stat.decls) do
        if decl.type then
            -- TODO: allow type annotations in the forward decl (and check them)
            return false
        end
    end

    return names
end

function Checker:check_stat_list(stats, is_toplevel)
    local N = #stats
    for i, first_stat in ipairs(stats) do
        -- Is this one of the special cases with forward declarations?
        -- If so, start by adding all those names to the scope
        local is_fresh_exported = (
            first_stat._tag == "ast.Stat.Func"
            and not first_stat.is_local
            and not first_stat._declared)
        local forward_decl_names = is_forward_decl(stats, i)
        if is_fresh_exported or forward_decl_names then

            local start
            if is_fresh_exported then
                assert(not forward_decl_names)
                start = i
            elseif forward_decl_names then
                assert(not is_fresh_exported)
                stats[i]._skip = true
                start = i+1
            else
                error("impossible")
            end

            for j = start, N do
                local stat = stats[j]
                if stat._tag == "ast.Stat.Func" and not stat.is_local then
                    if #stat.fields == 0 and not stat.method then
                        if not forward_decl_names or not forward_decl_names[stat.root] then
                            scope_error(stat.loc, "function '%s' was not forward declared", stat.root)
                        end
                        forward_decl_names[stat.root] = nil
                    end
                    self:add_func_stat_to_scope(stat, is_toplevel)
                else
                    break
                end
            end
        end
        -- And then type check the body of the statement
        self:check_stat(first_stat, is_toplevel)
    end
end

function Checker:check_stat(stat, is_toplevel)
    local tag = stat._tag
    if     tag == "ast.Stat.Decl" then
        if stat._skip then
            -- Ignore

        elseif self:is_a_module_declaration(stat.decls) then
            if self.module_symbol then
                type_error(stat.loc, "There can only be one module declaration in the program")
            end
            if not is_toplevel then
                type_error(stat.loc, "The module declaration must be at the toplevel") --TODO test
            end
            if #stat.decls ~= 1 or #stat.exps ~= 1 then
                type_error(stat.loc, "Cannot declare module table in a multiple-assignment") -- TODO test
            end

            local decl = stat.decls[1]
            local exp  = stat.exps[1]
            if not (exp._tag == "ast.Exp.Initlist" and #exp.fields == 0) then
                type_error(stat.loc, "Module initializer must be literally {}") -- TODO: test
            end

            stat._skip = true
            self.module_symbol = self:add_module_symbol(decl.name, false, {})
            self.module_var_name = decl.name

        else
            self:expand_function_returns(stat.exps)
            for i, decl in ipairs(stat.decls) do
                stat.exps[i] = self:check_initializer_exp(
                    decl, stat.exps[i],
                    "declaration of local variable %s", decl.name)
            end
            --assert(#stat.decls == #stat.exps) -- TODO this is a bad assumption
            for _, decl in ipairs(stat.decls) do
                self:add_value_symbol(decl.name, decl._type, checker.Def.Variable(decl))
            end
        end

    elseif tag == "ast.Stat.Block" then
        self.symbol_table:with_block(function()
            self:check_stat_list(stat.stats, false)
        end)

    elseif tag == "ast.Stat.While" then
        stat.condition = self:check_exp_synthesize(stat.condition)
        check_type_is_condition(stat.condition, "while loop condition")
        self:check_stat(stat.block, false)

    elseif tag == "ast.Stat.Repeat" then
        assert(stat.block._tag == "ast.Stat.Block")
        self.symbol_table:with_block(function()
            self:check_stat_list(stat.block.stats, false)
            stat.condition = self:check_exp_synthesize(stat.condition)
            check_type_is_condition(stat.condition, "repeat-until loop condition")
        end)

    elseif tag == "ast.Stat.ForNum" then

        stat.start = self:check_initializer_exp(
            stat.decl, stat.start,
            "numeric for-loop initializer")

        local loop_type = stat.decl._type

        if  loop_type._tag ~= "types.T.Integer" and
            loop_type._tag ~= "types.T.Float"
        then
            type_error(stat.decl.loc,
                "expected integer or float but found %s in for-loop control variable '%s'",
                types.tostring(loop_type), stat.decl.name)
        end

        if not stat.step then
            if     loop_type._tag == "types.T.Integer" then
                stat.step = ast.Exp.Integer(stat.limit.loc, 1)
            elseif loop_type._tag == "types.T.Float" then
                stat.step = ast.Exp.Float(stat.limit.loc, 1.0)
            else
                typedecl.tag_error(loop_type._tag, "loop type is not a number.")
            end
        end

        stat.limit = self:check_exp_verify(stat.limit, loop_type, "numeric for-loop limit")
        stat.step = self:check_exp_verify(stat.step, loop_type, "numeric for-loop step")

        self.symbol_table:with_block(function()
            self:add_value_symbol(stat.decl.name, stat.decl._type, checker.Def.Variable(stat.decl))
            self:check_stat(stat.block, false)
        end)

    elseif tag == "ast.Stat.ForIn" then
        local rhs = stat.exps
        self:expand_function_returns(rhs)

        if not rhs[1] then
            type_error(stat.loc, "missing right hand side of for-in loop")
        end

        if not rhs[2] then
            type_error(rhs[1].loc, "missing state variable in for-in loop")
        end

        if not rhs[3] then
            type_error(rhs[1].loc, "missing control variable in for-in loop")
        end

        local decl_types = {}
        for _ = 1, #stat.decls do
            table.insert(decl_types, types.T.Any())
        end

        local itertype = types.T.Function({ types.T.Any(), types.T.Any() }, decl_types)
        rhs[1] = self:check_exp_synthesize(rhs[1])
        local iteratorfn = rhs[1]

        if not types.equals(iteratorfn._type, itertype) then
            if iteratorfn._type._tag == "types.T.Function" and
               #decl_types ~= #iteratorfn._type.ret_types then
                type_error(iteratorfn.loc, "expected %d variable(s) in for loop but found %d",
                    #iteratorfn._type.ret_types, #decl_types)
            else
                type_error(iteratorfn.loc, "expected %s but found %s in loop iterator",
                    types.tostring(itertype), types.tostring(iteratorfn._type))
            end
        end

        rhs[2] = self:check_exp_synthesize(rhs[2])
        rhs[3] = self:check_exp_synthesize(rhs[3])

        if rhs[2]._type._tag ~= "types.T.Any" then
            type_error(rhs[2].loc, "expected any but found %s in loop state value",
                types.tostring(rhs[2]._type))
        end

        if rhs[3]._type._tag ~= "types.T.Any" then
            type_error(rhs[2].loc, "expected any but found %s in loop control value",
            types.tostring(rhs[3]._type))
        end

        if #stat.decls ~= #iteratorfn._type.ret_types then
            type_error(stat.decls[1].loc, "expected %d values, but function returns %d",
                       #stat.decls, #iteratorfn._type.ret_types)
        end

        self.symbol_table:with_block(function()
            local ret_types = iteratorfn._type.ret_types
            for i, decl in ipairs(stat.decls) do
                if decl.type then
                    decl._type = self:from_ast_type(decl.type)
                    if not types.consistent(decl._type, ret_types[i]) then
                        type_error(decl.loc, "expected value of type %s, but iterator returns %s",
                                   types.tostring(decl._type), types.tostring(ret_types[i]))
                    end
                else
                    stat.decls[i]._type = ret_types[i]
                end
                self:add_value_symbol(decl.name, decl._type, checker.Def.Variable(decl))
            end
            self:check_stat(stat.block, false)
        end)

    elseif tag == "ast.Stat.Assign" then
        self:expand_function_returns(stat.exps)

        local declarations = {}

        for i, var in ipairs(stat.vars) do
            if var._tag == "ast.Var.Dot" and self:is_the_module_variable(var.exp) then
                -- Declaring a module field
                if not is_toplevel then
                    scope_error(var.loc, "module fields can only be set at the toplevel")
                end
                if self.module_symbol.symbols[var.name] or declarations[var.name] then
                    multiple_definitions_error(var.loc, var.name)
                end
                declarations[var.name] = i
            else
                -- Regular assignment
                stat.vars[i] = self:check_var(stat.vars[i])
                if stat.vars[i]._def and stat.vars[i]._def._tag ~= "checker.Def.Variable" then
                    type_error(stat.loc, "LHS of assignment is not a mutable variable")
                end
            end
        end

        for i = 1, #stat.exps do
            local var = stat.vars[i]
            if var and var._type then
                -- Regular assignment
                stat.exps[i] = self:check_exp_verify(stat.exps[i], var._type, "assignment")
            else
                -- Module field or excess initializer
                stat.exps[i] = self:check_exp_synthesize(stat.exps[i])
            end
        end

        -- Add the declared module fields to scope after we type checked the initializers
        -- Order does not matter because names are distinct
        for name, i in pairs(declarations) do
            local var = stat.vars[i]
            local typ = stat.exps[i]._type

            local qvar = ast.Var.Name(var.loc, var.name)
            qvar._type = typ
            qvar._def = checker.Def.Variable(qvar)
            qvar._is_exported = true

            self.module_symbol.symbols[name] = checker.Symbol.Value(typ, qvar._def)
            stat.vars[i] = qvar
        end

    elseif tag == "ast.Stat.Call" then
        stat.call_exp = self:check_exp_synthesize(stat.call_exp)

    elseif tag == "ast.Stat.Return" then
        self:expand_function_returns(stat.exps)
        if #self.ret_types_stack == 0 then
            -- Module return
            if not is_toplevel then
                type_error(stat.loc, "return statement is not allowed here") -- TODO
            end
            if #stat.exps ~= 1 then
                type_error(stat.loc, "returning %d value(s) but module expects 1", #stat.exps) -- TODO
            end
            if not self:is_the_module_variable(stat.exps[1]) then
                type_error(stat.loc, "must return the module variable (%s)", self.module_var_name)  -- TODO
            end
            stat._skip = true
        else
            -- Function return
            local ret_types = assert(self.ret_types_stack[#self.ret_types_stack])
            if #stat.exps ~= #ret_types then
                type_error(stat.loc,
                    "returning %d value(s) but function expects %s",
                    #stat.exps, #ret_types)
            end
            for i = 1, #stat.exps do
                stat.exps[i] = self:check_exp_verify(stat.exps[i], ret_types[i], "return statement")
            end
        end

    elseif tag == "ast.Stat.If" then
        stat.condition = self:check_exp_synthesize(stat.condition)
        check_type_is_condition(stat.condition, "if statement condition")
        self:check_stat(stat.then_, false)
        self:check_stat(stat.else_, false)

    elseif tag == "ast.Stat.Break" then
        -- ok

    elseif tag == "ast.Stat.Func" then
        if not stat._declared then
            self:add_func_stat_to_scope(stat, is_toplevel)
        end
        stat.value = self:check_exp_verify(stat.value, stat._type, "toplevel function")

    else
        typedecl.tag_error(tag)
    end

    return stat
end

--
-- If the given var is of the form x.y.z, try to convert it to a Var.Name
--
function Checker:try_flatten_to_qualified_name(outer_var)
    -- TODO: We use O(N²) time if there is a long chain of dots that is not a qualified name.
    --       It might be possible to avoid this with a bit of memoization.

    if outer_var._tag ~= "ast.Var.Dot" then return false end

    -- Find the leftmost name.
    local rev_fields = {}
    local var = outer_var
    while var._tag == "ast.Var.Dot" do
        if var.exp._tag ~= "ast.Exp.Var" then return false end
        table.insert(rev_fields, var.name)
        var = var.exp.var
    end

    if var._tag ~= "ast.Var.Name" then return false end
    local root = var.name

    -- Is it a module? If so, resolve the types
    local root_sym = self.symbol_table:find_symbol(root)
    if not root_sym then return false end

    local fields = {}
    for i = #rev_fields, 1, -1 do
        table.insert(fields, rev_fields[i])
    end

    local sym = root_sym
    for _, field in ipairs(fields) do
        if sym._tag ~= "checker.Symbol.Module" then return false end -- Retry recursively.
        sym = sym.symbols[field]
        if not sym then
            type_error(outer_var.loc, "module field '%s' does not exist", field) -- TODO
        end
    end

    if sym._tag ~= "checker.Symbol.Value" then
        type_error(outer_var.loc, "module field '%s' is not a value", rev_fields[1]) -- TODO
    end

    local components = {}
    table.insert(components, root)
    for _, field in ipairs(fields) do
        table.insert(components, field)
    end

    local q = ast.Var.Name(var.loc, table.concat(components, "."))
    q._type = sym.typ
    q._def  = sym.def
    return q
end

function Checker:check_var(var)
    local tag = var._tag
    if     tag == "ast.Var.Name" then
        local sym = self.symbol_table:find_symbol(var.name)
        if not sym then
            scope_error(var.loc, "variable '%s' is not declared", var.name)
        end

        local stag = sym._tag
        if     stag == "checker.Symbol.Type" then
            type_error(var.loc, "'%s' is not a value", var.name)
        elseif stag == "checker.Symbol.Value" then
            var._type = sym.typ
            var._def  = sym.def
        elseif stag == "checker.Symbol.Module" then
            type_error(var.loc, "attempt to use module as a value")
        else
            typedecl.tag_error(stag)
        end

    elseif tag == "ast.Var.Dot" then

        local qualified = self:try_flatten_to_qualified_name(var)
        if qualified then return qualified end

        var.exp = self:check_exp_synthesize(var.exp)
        local ind_type = var.exp._type
        if not types.is_indexable(ind_type) then
            type_error(var.loc,
                "trying to access a member of a value of type '%s'",
                types.tostring(ind_type))
        end
        local field_type = types.indices(ind_type)[var.name]
        if not field_type then
            type_error(var.loc,
                "field '%s' not found in type '%s'",
                var.name, types.tostring(ind_type))
        end
        var._type = field_type

    elseif tag == "ast.Var.Bracket" then
        var.t = self:check_exp_synthesize(var.t)
        local arr_type = var.t._type
        if arr_type._tag ~= "types.T.Array" then
            type_error(var.t.loc,
                "expected array but found %s in array indexing",
                types.tostring(arr_type))
        end
        var.k = self:check_exp_verify(var.k, types.T.Integer(), "array indexing")
        var._type = arr_type.elem

    else
        typedecl.tag_error(tag)
    end
    return var
end

local function is_numeric_type(typ)
    return typ._tag == "types.T.Integer" or typ._tag == "types.T.Float"
end

function Checker:coerce_numeric_exp_to_float(exp)
    local tag = exp._type._tag
    if     tag == "types.T.Float" then
        return exp
    elseif tag == "types.T.Integer" then
        return self:check_exp_synthesize(ast.Exp.ToFloat(exp.loc, exp))
    elseif typedecl.match_tag(tag, "types.T") then
        typedecl.tag_error(tag, "this type cannot be coerced to float.")
    else
        typedecl.tag_error(tag)
    end
end

-- Infers the type of expression @exp, ignoring the surrounding type context.
-- Returns the typechecked expression. This may be either the original expression, or an inner
-- expression if we are dropping a redundant type conversion.
function Checker:check_exp_synthesize(exp)
    if exp._type then
        -- This expression was already type-checked before, probably due to expand_function_returns.
        return exp
    end

    local tag = exp._tag
    if     tag == "ast.Exp.Nil" then
        exp._type = types.T.Nil()

    elseif tag == "ast.Exp.Bool" then
        exp._type = types.T.Boolean()

    elseif tag == "ast.Exp.Integer" then
        exp._type = types.T.Integer()

    elseif tag == "ast.Exp.Float" then
        exp._type = types.T.Float()

    elseif tag == "ast.Exp.String" then
        exp._type = types.T.String()

    elseif tag == "ast.Exp.Initlist" then
        type_error(exp.loc, "missing type hint for initializer")

    elseif tag == "ast.Exp.Lambda" then
        type_error(exp.loc, "missing type hint for lambda")

    elseif tag == "ast.Exp.Var" then
        exp.var = self:check_var(exp.var)
        exp._type = exp.var._type

    elseif tag == "ast.Exp.Unop" then
        exp.exp = self:check_exp_synthesize(exp.exp)
        local t = exp.exp._type
        local op = exp.op
        if op == "#" then
            if t._tag ~= "types.T.Array" and t._tag ~= "types.T.String" then
                type_error(exp.loc,
                    "trying to take the length of a %s instead of an array or string",
                    types.tostring(t))
            end
            exp._type = types.T.Integer()
        elseif op == "-" then
            if t._tag ~= "types.T.Integer" and t._tag ~= "types.T.Float" then
                type_error(exp.loc,
                    "trying to negate a %s instead of a number",
                    types.tostring(t))
            end
            exp._type = t
        elseif op == "~" then
            if t._tag ~= "types.T.Integer" then
                type_error(exp.loc,
                    "trying to bitwise negate a %s instead of an integer",
                    types.tostring(t))
            end
            exp._type = types.T.Integer()
        elseif op == "not" then
            check_type_is_condition(exp.exp, "'not' operator")
            exp._type = types.T.Boolean()
        else
            typedecl.tag_error(op)
        end

    elseif tag == "ast.Exp.Binop" then
        exp.lhs = self:check_exp_synthesize(exp.lhs)
        exp.rhs = self:check_exp_synthesize(exp.rhs)
        local t1 = exp.lhs._type
        local t2 = exp.rhs._type
        local op = exp.op
        if op == "==" or op == "~=" then
            if (t1._tag == "types.T.Integer" and t2._tag == "types.T.Float") or
               (t1._tag == "types.T.Float"   and t2._tag == "types.T.Integer") then
                -- Note: if we implement this then we should use the same logic as luaV_equalobj.
                -- Don't just cast to float! That is not accurate for large integers.
                type_error(exp.loc,
                    "comparisons between float and integers are not yet implemented")
            end
            if not types.equals(t1, t2) then
                type_error(exp.loc,
                    "cannot compare %s and %s using %s",
                    types.tostring(t1), types.tostring(t2), op)
            end
            exp._type = types.T.Boolean()

        elseif op == "<" or op == ">" or op == "<=" or op == ">=" then
            if (t1._tag == "types.T.Integer" and t2._tag == "types.T.Integer") or
               (t1._tag == "types.T.Float"   and t2._tag == "types.T.Float") or
               (t1._tag == "types.T.String"  and t2._tag == "types.T.String") then
               -- OK
            elseif (t1._tag == "types.T.Integer" and t2._tag == "types.T.Float") or
                   (t1._tag == "types.T.Float"   and t2._tag == "types.T.Integer") then
                -- Note: if we implement this then we should use the same logic as LTintfloat,
                -- LEintfloat and so on, from lvm.c. Just casting to float is not enough!
                type_error(exp.loc,
                    "comparisons between float and integers are not yet implemented")
            else
                type_error(exp.loc,
                    "cannot compare %s and %s using %s",
                    types.tostring(t1), types.tostring(t2), op)
            end
            exp._type = types.T.Boolean()

        elseif op == "+" or op == "-" or op == "*" or op == "%" or op == "//" then
            if not is_numeric_type(t1) then
                type_error(exp.loc,
                    "left hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(t1))
            end
            if not is_numeric_type(t2) then
                type_error(exp.loc,
                    "right hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(t2))
            end

            if t1._tag == "types.T.Integer" and
               t2._tag == "types.T.Integer"
            then
                exp._type = types.T.Integer()
            else
                exp.lhs = self:coerce_numeric_exp_to_float(exp.lhs)
                exp.rhs = self:coerce_numeric_exp_to_float(exp.rhs)
                exp._type = types.T.Float()
            end

        elseif op == "/" or op == "^" then
            if not is_numeric_type(t1) then
                type_error(exp.loc,
                    "left hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(t1))
            end
            if not is_numeric_type(t2) then
                type_error(exp.loc,
                    "right hand side of arithmetic expression is a %s instead of a number",
                    types.tostring(t2))
            end

            exp.lhs = self:coerce_numeric_exp_to_float(exp.lhs)
            exp.rhs = self:coerce_numeric_exp_to_float(exp.rhs)
            exp._type = types.T.Float()

        elseif op == ".." then
            -- The arguments to '..' must be a strings. We do not allow "any" because Pallene does
            -- not allow concatenating integers or objects that implement tostring()
            if t1._tag ~= "types.T.String" then
                type_error(exp.loc, "cannot concatenate with %s value", types.tostring(t1))
            end
            if t2._tag ~= "types.T.String" then
                type_error(exp.loc, "cannot concatenate with %s value", types.tostring(t2))
            end
            exp._type = types.T.String()

        elseif op == "and" or op == "or" then
            check_type_is_condition(exp.lhs, "left hand side of '%s'", op)
            check_type_is_condition(exp.rhs, "right hand side of '%s'", op)
            exp._type = t2

        elseif op == "|" or op == "&" or op == "~" or op == "<<" or op == ">>" then
            if t1._tag ~= "types.T.Integer" then
                type_error(exp.loc,
                    "left hand side of bitwise expression is a %s instead of an integer",
                    types.tostring(t1))
            end
            if t2._tag ~= "types.T.Integer" then
                type_error(exp.loc,
                    "right hand side of bitwise expression is a %s instead of an integer",
                    types.tostring(t2))
            end
            exp._type = types.T.Integer()

        else
            typedecl.tag_error(op)
        end

    elseif tag == "ast.Exp.CallFunc" then
        exp.exp = self:check_exp_synthesize(exp.exp)
        local f_type = exp.exp._type

        if f_type._tag ~= "types.T.Function" then
            type_error(exp.loc,
                "attempting to call a %s value",
                types.tostring(exp.exp._type))
        end

        self:expand_function_returns(exp.args)

        if #f_type.arg_types ~= #exp.args then
            type_error(exp.loc,
                "function expects %d argument(s) but received %d",
                #f_type.arg_types, #exp.args)
        end

        for i = 1, #exp.args do
            exp.args[i] =
                self:check_exp_verify(
                    exp.args[i], f_type.arg_types[i],
                    "argument %d of call to function", i)
        end

        if #f_type.ret_types == 0 then
            exp._type = types.T.Void()
        else
            exp._type  = f_type.ret_types[1] or types.T.Void()
        end
        exp._types = f_type.ret_types

    elseif tag == "ast.Exp.CallMethod" then
        error("not implemented")

    elseif tag == "ast.Exp.Cast" then
        exp._type = self:from_ast_type(exp.target)
        exp.exp = self:check_exp_verify(exp.exp, exp._type, "cast expression")

        -- We check the child expression with verify instead of synthesize because Pallene cases
        -- also act as type annotations for things like empty array literals: ({} as {value}).
        -- However, this means that the call to verify almost always inserts a redundant cast node.
        -- To keep the --dump-checker output clean, we get rid of it.  By the way, the Pallene to
        -- Lua translator cares that we remove the inner one instead of the outer one because the
        -- outer one has source locations and the inner one doesn't.
        while
            exp.exp._tag == 'ast.Exp.Cast' and
            exp.exp.target == false and
            types.equals(exp.exp._type, exp._type)
        do
            exp.exp = exp.exp.exp
        end

    elseif tag == "ast.Exp.Paren" then
        exp.exp = self:check_exp_synthesize(exp.exp)
        exp._type = exp.exp._type

    elseif tag == "ast.Exp.ExtraRet" then
        exp._type = exp.call_exp._types[exp.i]

    elseif tag == "ast.Exp.ToFloat" then
        assert(exp.exp._type._tag == "types.T.Integer")
        exp._type = types.T.Float()

    else
        typedecl.tag_error(tag)
    end

    return exp
end

-- Verifies that expression @exp has type expected_type.
-- Returns the typechecked expression. This may be either the original
-- expression, or a coercion node from the original expression to the expected
-- type.
--
-- errmsg_fmt: format string describing where we got @expected_type from
-- ... : arguments to the "errmsg_fmt" format string
function Checker:check_exp_verify(exp, expected_type, errmsg_fmt, ...)
    if not expected_type then
        error("expected_type is required")
    end

    local tag = exp._tag
    if tag == "ast.Exp.Initlist" then

        if expected_type._tag == "types.T.Array" then
            for _, field in ipairs(exp.fields) do
                local ftag = field._tag
                if ftag == "ast.Field.Rec" then
                    type_error(field.loc,
                        "named field '%s' in array initializer",
                        field.name)
                elseif ftag == "ast.Field.List" then
                    field.exp = self:check_exp_verify(
                        field.exp, expected_type.elem,
                        "array initializer")
                else
                    typedecl.tag_error(ftag)
                end
            end
        elseif expected_type._tag == "types.T.Module" then
            -- Fallthrough to default

        elseif types.is_indexable(expected_type) then
            local initialized_fields = {}
            for _, field in ipairs(exp.fields) do
                local ftag = field._tag
                if ftag == "ast.Field.List" then
                    type_error(field.loc,
                        "table initializer has array part")
                elseif ftag == "ast.Field.Rec" then
                    if initialized_fields[field.name] then
                        type_error(field.loc,
                            "duplicate field '%s' in table initializer",
                            field.name)
                    end
                    initialized_fields[field.name] = true

                    local field_type = types.indices(expected_type)[field.name]
                    if not field_type then
                        type_error(field.loc,
                            "invalid field '%s' in table initializer for %s",
                            field.name, types.tostring(expected_type))
                    end

                    field.exp = self:check_exp_verify(
                        field.exp, field_type,
                        "table initializer")
                else
                    typedecl.tag_error(ftag)
                end
            end

            for field_name, _ in pairs(types.indices(expected_type)) do
                if not initialized_fields[field_name] then
                    type_error(exp.loc,
                        "required field '%s' is missing from initializer",
                        field_name)
                end
            end
        else
            type_error(exp.loc,
                "type hint for initializer is not an array, table, or record type")
        end

    elseif tag == "ast.Exp.Lambda" then

        -- These assertions are always true in the current version of Pallene, which does not allow
        -- nested function expressions. Once we add function expressions to the parser then we
        -- should convert these assertions into proper calls to type_error.
        assert(expected_type._tag == "types.T.Function")
        assert(#expected_type.arg_types == #exp.arg_decls)

        table.insert(self.ret_types_stack, expected_type.ret_types)
        self.symbol_table:with_block(function()
            for i, decl in ipairs(exp.arg_decls) do
                decl._type = assert(expected_type.arg_types[i])
                self:add_value_symbol(decl.name, decl._type, checker.Def.Variable(decl))
            end
            self:check_stat(exp.body, false)
        end)
        table.remove(self.ret_types_stack)

    elseif tag == "ast.Exp.Paren" then
        exp.exp = self:check_exp_verify(exp.exp, expected_type, errmsg_fmt, ...)

    else

        exp = self:check_exp_synthesize(exp)
        local found_type = exp._type

        if not types.equals(found_type, expected_type) then
            if types.consistent(found_type, expected_type) then
                exp = ast.Exp.Cast(exp.loc, exp, false)

            else
                type_error(exp.loc, string.format(
                    "expected %s but found %s in %s",
                    types.tostring(expected_type),
                    types.tostring(found_type),
                    string.format(errmsg_fmt, ...)))
            end
        end
    end

    -- If we have reached this point, the type should be correct. But to be safe, we assert that the
    -- type annotation is correct, if it has already been set by check_exp_synthesize.
    exp._type = exp._type or expected_type
    assert(types.equals(exp._type, expected_type))

    -- Be aware that some of the cases might have reassigned the `exp` variable so it won't
    -- necessarily be the same as the input `exp` we received.
    return exp
end

-- Typechecks an initializer `x : ast_typ = exp`, where the type annotation is optional.
-- Sets decl._type and exp._type
function Checker:check_initializer_exp(decl, exp, err_fmt, ...)
    if decl.type then
        decl._type = self:from_ast_type(decl.type)
        if exp ~= nil then
            return self:check_exp_verify(exp, decl._type, err_fmt, ...)
        else
            return nil
        end
    else
        if exp ~= nil then
            local e = self:check_exp_synthesize(exp)
            decl._type = e._type
            return e
        else
            type_error(decl.loc, string.format(
                "uninitialized variable '%s' needs a type annotation",
                decl.name))
        end
    end
end

return checker
