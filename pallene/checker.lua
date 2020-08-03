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
-- This file is responsible for type-checking a Pallene module and for resolving the scope of all
-- identifiers. The result is a modified AST that is annotated with this information:
--
--   * _type: A types.T in the following kinds of nodes
--      - ast.Exp
--      - ast.Var
--      - ast.Decl
--      - ast.Toplevel.Record
--
--   * _name: In ast.Var.Name nodes, a checker.Name that points to the matching declaration.
--
-- We also make some adjustments to the AST:
--
--   * We convert qualified identifiers such as `io.write` from ast.Var.Dot to a flat ast.Var.Name.
--   * We insert explicit ast.Exp.Cast nodes where there is an implicit upcast or downcast.
--   * We insert ast.Exp.ExtraRet nodes to represent additional return values from functions.
--   * We insert an explicit call to tofloat in some arithmetic operations. For example int + float.
--   * We add an explicit +1 or +1.0 step in numeric for loops without a loop step.
--
-- In order for these transformations to work it is important to always use the return value from
-- the check_exp and check_var functions. For example, instead of just `check_exp(foo.exp)` you
-- should write `foo.exp = check_exp(foo.exp)`.
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

-- Usually if an error is produced with `assert()` or `error()` then it is
-- a compiler bug. User-facing errors such as syntax errors and
-- type checking errors are reported in a different way. The actual
-- method employed is kind of tricky. Since Lua does not have a clean
-- try-catch functionality we use coroutines to do that job.
-- You can see this in the `checker.check()` function but you do
-- not need to know how it works. You just need to know that calling
-- `scope_error()` or `type_error()` will exit the type checking routine
-- and report a Pallene compilation error.
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
    self.symbol_table = symtab.new() -- string => checker.Name
    self.ret_types_stack = {}        -- stack of types.T
    return self
end


--
-- Symbol table
--

local function declare_type(type_name, cons)
    typedecl.declare(checker, "checker", type_name, cons)
end

declare_type("Name", {
    Type     = { "typ" },
    Local    = { "decl" },
    Global   = { "decl" },
    Function = { "decl" },
    Builtin  = { "name" },
    Module   = { "name" }
})

function Checker:add_type(name, typ)
    assert(string.match(typ._tag, "^types%.T%."))
    self.symbol_table:add_symbol(name, checker.Name.Type(typ))
end

function Checker:add_local(decl)
    assert(decl._tag == "ast.Decl.Decl")
    self.symbol_table:add_symbol(decl.name, checker.Name.Local(decl))
end

function Checker:add_global(decl)
    assert(decl._tag == "ast.Decl.Decl")
    self.symbol_table:add_symbol(decl.name, checker.Name.Global(decl))
end

function Checker:add_function(decl)
    assert(decl._tag == "ast.Decl.Decl")
    self.symbol_table:add_symbol(decl.name, checker.Name.Function(decl))
end

function Checker:add_builtin(name, id)
    assert(type(name) == "string")
    self.symbol_table:add_symbol(name, checker.Name.Builtin(id))
end

function Checker:add_module(name)
    assert(type(name) == "string")
    self.symbol_table:add_symbol(name, checker.Name.Module(name))
end

--
--
--

function Checker:from_ast_type(ast_typ)
    local tag = ast_typ._tag
    if     tag == "ast.Type.Nil" then
        return types.T.Nil()

    elseif tag == "ast.Type.Boolean" then
        return types.T.Boolean()

    elseif tag == "ast.Type.Integer" then
        return types.T.Integer()

    elseif tag == "ast.Type.Float" then
        return types.T.Float()

    elseif tag == "ast.Type.String" then
        return types.T.String()

    elseif tag == "ast.Type.Any" then
        return types.T.Any()

    elseif tag == "ast.Type.Name" then
        local name = ast_typ.name
        local cname = self.symbol_table:find_symbol(name)
        if not cname then
            scope_error(ast_typ.loc,  "type '%s' is not declared", name)
        end
        if cname._tag ~= "checker.Name.Type" then
            type_error(ast_typ.loc, "'%s' isn't a type", name)
        end
        return cname.typ

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
        error("impossible")
    end
end

local letrec_groups = {
    ["ast.Toplevel.Import"]    = "Import",
    ["ast.Toplevel.Var"]       = "Var",
    ["ast.Toplevel.Func"]      = "Func",
    ["ast.Toplevel.Typealias"] = "Type",
    ["ast.Toplevel.Record"]    = "Type",
}

function Checker:check_program(prog_ast)

    do
        -- Forbid top-level duplicates
        --
        -- To avoid ambiguities that could happen if the programmer tried to declare
        -- multiple toplevel entities with the same name, we give a compilation
        -- error.
        local names = {}
        for _, top_level_node in ipairs(prog_ast) do
            local top_level_names = ast.toplevel_names(top_level_node)
            local node_location = top_level_node.loc
            for _, name in ipairs(top_level_names) do
                local old_location = names[name]
                if old_location then
                    scope_error(node_location,
                        "duplicate toplevel '%s', previous one at line %d",
                        name, old_location.line)
                end
                names[name] = node_location
            end
        end
    end

    -- Add builtins to symbol table. The order does not matter because they are distinct.
    for name, _ in pairs(builtins.functions) do
        self:add_builtin(name, name)
    end
    for name in pairs(builtins.modules) do
        self:add_module(name)
    end

    -- Group mutually-recursive definitions
    local tl_groups = {}
    do
        local i = 1
        local N = #prog_ast
        while i <= N do
            local node1 = prog_ast[i]
            local tag1  = node1._tag
            assert(letrec_groups[tag1])

            local group = { node1 }
            local j = i + 1
            while j <= N do
                local node2 = prog_ast[j]
                local tag2  = node2._tag
                assert(letrec_groups[tag2])

                if letrec_groups[tag1] ~= letrec_groups[tag2] then
                    break
                end

                table.insert(group, node2)
                j = j + 1
            end
            table.insert(tl_groups, group)
            i = j
        end
    end

    -- Check toplevel
    for _, tl_group in ipairs(tl_groups) do
        local group_kind = letrec_groups[tl_group[1]._tag]

        if     group_kind == "Import" then
            local loc = tl_group[1].loc
            type_error(loc, "modules are not implemented yet")

        elseif group_kind == "Var" then

            for _, tl_var in ipairs(tl_group) do

                self:expand_function_returns(tl_var.decls, tl_var.values)

                for i, decl in ipairs(tl_var.decls) do
                    tl_var.values[i] =
                        self:check_initializer_exp(
                            decl, tl_var.values[i],
                            "declaration of module variable %s", decl.name)
                end

                for _, decl in ipairs(tl_var.decls) do
                    self:add_global(decl)
                end
            end


        elseif group_kind == "Func" then

            for _, tl_func in ipairs(tl_group) do
                local decl = tl_func.decl
                decl._type = self:from_ast_type(decl.type)
                self:add_function(decl)
            end

            for _, tl_func in ipairs(tl_group) do
                tl_func.value =
                    self:check_exp_verify(tl_func.value, tl_func.decl._type, "toplevel function")
            end

        elseif group_kind == "Type" then

            -- TODO: Implement recursive and mutually recursive types
            for _, tl_node in ipairs(tl_group) do
                local tag = tl_node._tag
                if     tag == "ast.Toplevel.Typealias" then
                    self:add_type(tl_node.name, self:from_ast_type(tl_node.type))

                elseif tag == "ast.Toplevel.Record" then
                    local field_names = {}
                    local field_types = {}
                    for _, field_decl in ipairs(tl_node.field_decls) do
                        local field_name = field_decl.name
                        table.insert(field_names, field_name)
                        field_types[field_name] = self:from_ast_type(field_decl.type)
                    end

                    local typ = types.T.Record(tl_node.name, field_names, field_types)
                    tl_node._type = typ
                    self:add_type(tl_node.name, typ)

                else
                    error("impossible")
                end
            end

        else
            error("impossible")
        end
    end

    return prog_ast
end

-- This function expands @rhs using @rhs[#rhs] if there are missing expressions.
-- That is, if (rhs < lhs) and rhs[#rhs] is a function or method call.
function Checker:expand_function_returns(lhs, rhs)
    local last = rhs[#rhs]
    if  last and (last._tag == "ast.Exp.CallFunc" or
        last._tag == "ast.Exp.CallMethod")
    then
        local missing_exps = #lhs - #rhs

        last = self:check_exp_synthesize(last)
        rhs[#rhs] = last

        for i = 2, missing_exps + 1 do
            if last._types[i] then
                local exp = ast.Exp.ExtraRet(last.loc, last, i)
                table.insert(rhs, exp)
            end
        end
    end
end

function Checker:check_stat(stat)
    local tag = stat._tag
    if     tag == "ast.Stat.Decl" then

        self:expand_function_returns(stat.decls, stat.exps)

        for i, decl in ipairs(stat.decls) do
            stat.exps[i] =
                self:check_initializer_exp(
                    decl, stat.exps[i],
                    "declaration of local variable %s", decl.name)
        end

        for _, decl in ipairs(stat.decls) do
            self:add_local(decl)
        end

    elseif tag == "ast.Stat.Block" then
        self.symbol_table:with_block(function()
            for _, inner_stat in ipairs(stat.stats) do
                self:check_stat(inner_stat)
            end
        end)

    elseif tag == "ast.Stat.While" then
        stat.condition = self:check_exp_synthesize(stat.condition)
        check_type_is_condition(stat.condition, "while loop condition")
        self:check_stat(stat.block)

    elseif tag == "ast.Stat.Repeat" then
        assert(stat.block._tag == "ast.Stat.Block")
        self.symbol_table:with_block(function()
            for _, inner_stat in ipairs(stat.block.stats) do
                self:check_stat(inner_stat)
            end
            stat.condition = self:check_exp_synthesize(stat.condition)
            check_type_is_condition(stat.condition, "repeat-until loop condition")
        end)

    elseif tag == "ast.Stat.For" then

        stat.start =
            self:check_initializer_exp(
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
                error("impossible")
            end
        end

        stat.limit = self:check_exp_verify(stat.limit, loop_type, "numeric for-loop limit")
        stat.step = self:check_exp_verify(stat.step, loop_type, "numeric for-loop step")

        self.symbol_table:with_block(function()
            self:add_local(stat.decl)
            self:check_stat(stat.block)
        end)

    elseif tag == "ast.Stat.Assign" then
        self:expand_function_returns(stat.vars, stat.exps)

        for i = 1, #stat.vars do
            stat.vars[i] = self:check_var(stat.vars[i])
            if stat.vars[i]._tag == "ast.Var.Name" then
                local ntag = stat.vars[i]._name._tag
                if ntag == "checker.Name.Function" then
                    type_error(stat.loc,
                        "attempting to assign to toplevel constant function '%s'",
                        stat.vars[i].name)
                elseif ntag == "checker.Name.Builtin" then
                    type_error(stat.loc,
                        "attempting to assign to builtin function %s",
                        stat.vars[i].name)
                end
            end
            stat.exps[i] = self:check_exp_verify(stat.exps[i], stat.vars[i]._type, "assignment")
        end

    elseif tag == "ast.Stat.Call" then
        stat.call_exp = self:check_exp_synthesize(stat.call_exp)

    elseif tag == "ast.Stat.Return" then
        local ret_types = assert(self.ret_types_stack[#self.ret_types_stack])

        self:expand_function_returns(ret_types, stat.exps)

        if #stat.exps ~= #ret_types then
            type_error(stat.loc,
                "returning %d value(s) but function expects %s",
                #stat.exps, #ret_types)
        end

        for i = 1, #stat.exps do
            stat.exps[i] = self:check_exp_verify(stat.exps[i], ret_types[i], "return statement")
        end

    elseif tag == "ast.Stat.If" then
        stat.condition = self:check_exp_synthesize(stat.condition)
        check_type_is_condition(stat.condition, "if statement condition")
        self:check_stat(stat.then_)
        self:check_stat(stat.else_)

    elseif tag == "ast.Stat.Break" then
        -- ok

    else
        error("impossible")
    end

    return stat
end

function Checker:check_var(var)
    local tag = var._tag
    if     tag == "ast.Var.Name" then
        local cname = self.symbol_table:find_symbol(var.name)
        if not cname then
            scope_error(var.loc, "variable '%s' is not declared", var.name)
        end
        var._name = cname

        if     cname._tag == "checker.Name.Type" then
            type_error(var.loc, "'%s' isn't a value", var.name)
        elseif cname._tag == "checker.Name.Local" then
            var._type = assert(cname.decl._type)
        elseif cname._tag == "checker.Name.Global" then
            var._type = assert(cname.decl._type)
        elseif cname._tag == "checker.Name.Function" then
            var._type = assert(cname.decl._type)
        elseif cname._tag == "checker.Name.Builtin" then
            var._type = assert(builtins.functions[cname.name])
        elseif cname._tag == "checker.Name.Module" then
            -- Module names can appear only in the dot notation.
            -- For example, a statement like `local x = io` is illegal.
            type_error(var.loc,
                "cannot reference module name '%s' without dot notation",
                var.name)
        else
            error("impossible")
        end

    elseif tag == "ast.Var.Dot" then
        if var.exp._tag == "ast.Exp.Var" and
           var.exp.var._tag == "ast.Var.Name" and
           builtins.modules[var.exp.var.name] then
            local module_name = var.exp.var.name
            local function_name = var.name
            local internal_name = module_name .. "." .. function_name

            local typ = builtins.functions[internal_name]
            if typ then
                local cname = self.symbol_table:find_symbol(internal_name)
                local flat_var = ast.Var.Name(var.exp.loc, internal_name)
                flat_var._name = cname
                flat_var._type = typ
                var = flat_var
            else
                type_error(var.loc,
                    "unknown function '%s'", internal_name)
            end
        else
            var.exp = self:check_exp_synthesize(var.exp)
            local ind_type = var.exp._type
            if not types.is_indexable(ind_type) then
                type_error(var.loc,
                    "trying to access a member of value of type '%s'",
                    types.tostring(ind_type))
            end
            local field_type = types.indices(ind_type)[var.name]
            if not field_type then
                type_error(var.loc,
                    "field '%s' not found in type '%s'",
                    var.name, types.tostring(ind_type))
            end
            var._type = field_type
        end
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
        error("impossible")
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
    else
        error("impossible")
    end
end

-- Infers the type of expression @exp, ignoring the surrounding type context.
-- Returns the typechecked expression. This may be either be the original expression, or an inner
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
            error("impossible")
        end

    elseif tag == "ast.Exp.Concat" then
        for _, inner_exp in ipairs(exp.exps) do
            inner_exp = self:check_exp_synthesize(inner_exp)
            local t = inner_exp._type
            if t._tag ~= "types.T.String" then
                type_error(inner_exp.loc,
                    "cannot concatenate with %s value",
                    types.tostring(t))
            end
        end
        exp._type = types.T.String()

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
            error("impossible")
        end

    elseif tag == "ast.Exp.CallFunc" then
        exp.exp = self:check_exp_synthesize(exp.exp)
        local f_type = exp.exp._type

        if f_type._tag ~= "types.T.Function" then
            type_error(exp.loc,
                "attempting to call a %s value",
                types.tostring(exp.exp._type))
        end

        self:expand_function_returns(f_type.arg_types, exp.args)

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
        error("impossible")
    end

    return exp
end

-- Verifies that expression @exp has type expected_type.
-- Returns the typechecked expression. This may be either be the original
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
                if field.name then
                    type_error(field.loc,
                        "named field '%s' in array initializer",
                        field.name)
                end
                field.exp = self:check_exp_verify(
                    field.exp, expected_type.elem,
                    "array initializer")
            end

        elseif types.is_indexable(expected_type) then
            local initialized_fields = {}
            for _, field in ipairs(exp.fields) do
                if not field.name then
                    type_error(field.loc,
                        "table initializer has array part")
                end

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

        exp._type = expected_type
        return exp

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
                self:add_local(decl)
            end
            self:check_stat(exp.body)
        end)
        table.remove(self.ret_types_stack)

        return exp

    elseif tag == "ast.Exp.Paren" then
        exp.exp = self:check_exp_verify(exp.exp, expected_type, errmsg_fmt, ...)
        return exp

    else

        exp = self:check_exp_synthesize(exp)
        local found_type = exp._type
        if types.equals(found_type, expected_type) then
            return exp
        elseif types.consistent(found_type, expected_type) then
            local cast = ast.Exp.Cast(exp.loc, exp, false, false)
            cast._type = expected_type
            return cast
        else
            type_error(exp.loc, string.format(
                "expected %s but found %s in %s",
                types.tostring(expected_type),
                types.tostring(found_type),
                string.format(errmsg_fmt, ...)))
        end
    end
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
