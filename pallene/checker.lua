-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local ast = require "pallene.ast"
local builtins = require "pallene.builtins"
local ir = require "pallene.ir"
local location = require "pallene.location"
local symtab = require "pallene.symtab"
local types = require "pallene.types"
local typedecl = require "pallene.typedecl"
local util = require "pallene.util"

local checker = {}

local Checker
local FunChecker

--
--
--

-- ast.Exp.ExtraRet is a node that represents an extra return value of a
--     function call. This node is added to keep information about which return
--     value must be used.
-- @loc: This is the location of the function call
-- @call_exp: This is the actual function call
-- @i: This is the index of the return value of this node
-- @n: This is the total number of return values of the function

--
--
--


--
-- Typecheck
--


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
            local module = value
            return module, {}
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

local function checker_error(loc, fmt, ...)
    local err_msg = location.format_error(loc, fmt, ...)
    coroutine.yield(err_msg)
end

local function scope_error(loc, fmt, ...)
    return checker_error(loc, ("scope error: " .. fmt), ...)
end

local function type_error(loc, fmt, ...)
    return checker_error(loc, ("type error: " .. fmt), ...)
end

local function check_type_is_condition(exp, err_fmt, ...)
    local typ = exp._type
    if typ._tag ~= "types.T.Boolean" and typ._tag ~= "types.T.Any" then
        type_error(exp.loc,
            "expression passed to %s has type %s. Expected boolean or any.",
            string.format(err_fmt, ...),
            types.tostring(typ))
    end
end

--
--
--

local function declare_type(type_name, cons)
    typedecl.declare(checker, "checker", type_name, cons)
end

declare_type("Name", {
    Type     = {"typ"},
    Local    = {"id"},
    Global   = {"id"},
    Function = {"id"},
    Builtin  = {"name"},
})

--
--
--

Checker = util.Class()
function Checker:init()
    self.symbol_table = symtab.new() -- string => checker.Name
    self.module = ir.Module()        -- types, functions, etc
    return self
end

-- The environment and symbol table need to be updated in synchrony.

function Checker:add_record_type(name, typ)
    local _ = ir.add_record_type(self.module, typ)
    self.symbol_table:add_symbol(name, checker.Name.Type(typ))
    return typ
end

function Checker:add_function(loc, name, typ, body)
    local f_id = ir.add_function(self.module, loc, name, typ, body)
    self.symbol_table:add_symbol(name, checker.Name.Function(f_id))
    return f_id
end

function Checker:add_global(name, typ)
    local g_id = ir.add_global(self.module, name, typ)
    self.symbol_table:add_symbol(name, checker.Name.Global(g_id))
    return g_id
end

function Checker:add_builtin(name)
    self.symbol_table:add_symbol(name, checker.Name.Builtin(name))
end


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
                type_error(ast_typ.loc, "duplicate field '%s' in table",
                           field.name)
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

function Checker:check_top_level_name(names, name, loc)
    local old_loc = names[name]
    if old_loc then
        scope_error(loc,
            "duplicate toplevel declaration for '%s', previous one at line %d",
            name, old_loc.line)
    end
    names[name] = loc
end

function Checker:check_program(prog_ast)

    do
        -- Forbid toplevel duplicates
        local names = {}
        for _, tl_node in ipairs(prog_ast) do
            local tag = tl_node._tag

            if     tag == "ast.Toplevel.Var" then
                for _, decl in ipairs(tl_node.decls) do
                    self:check_top_level_name(names, decl.name, decl.loc)
                end

            elseif tag == "ast.Toplevel.Func" then
                self:check_top_level_name(names, ast.toplevel_name(tl_node),
                    tl_node.loc)

            elseif tag == "ast.Toplevel.Typealias" then
                self:check_top_level_name(names, ast.toplevel_name(tl_node),
                    tl_node.loc)

            elseif tag == "ast.Toplevel.Record" then
                self:check_top_level_name(names, ast.toplevel_name(tl_node),
                    tl_node.loc)

            elseif tag == "ast.Toplevel.Import" then
                self:check_top_level_name(names, ast.toplevel_name(tl_node),
                    tl_node.loc)

            elseif tag == "ast.Toplevel.Builtin" then
                self:check_top_level_name(names, ast.toplevel_name(tl_node),
                    tl_node.loc)

            else
                error("impossible")
            end
        end
    end

    -- Add builtins to symbol table.
    -- (The order does not matter because they are distinct)
    for name, _ in pairs(builtins) do
        self:add_builtin(name)
    end

    -- Add a special entry for $tofloat which can never be shadowed
    -- and is therefore always visible.
    self.symbol_table:add_symbol(
        "$tofloat",
        checker.Name.Builtin("tofloat"))

    local toplevel_f_id = self:add_function(
        false,
        "$init",
        types.T.Function({}, {}),
        ast.Stat.Block(false, {})
    )
    assert(toplevel_f_id == 1) -- coder currently assumes this
    local toplevel_stats = self.module.functions[toplevel_f_id].body.stats
    local toplevel_fun_checker = FunChecker.new(self, toplevel_f_id)

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
                local loc = tl_var.loc

                local last_val = tl_var.values[#tl_var.values]
                if last_val._tag == "ast.Exp.CallFunc" then
                    -- print(ii(last_val))
                    last_val = toplevel_fun_checker:check_exp_synthesize(last_val)
                    if last_val._types and #last_val._types > 1 then
                        for i = 2, #last_val._types do
                            local nval= ast.Exp.ExtraRet(last_val.loc, last_val, i,
                                            #last_val._types)
                            nval._type = last_val._types[i]
                            table.insert(tl_var.values, nval)
                        end
                    end
                end
                if #tl_var.decls ~= #tl_var.values then
                    type_error(tl_var.loc,
                        "left-hand side expects %d value(s) but right-hand " ..
                        "side produces %d value(s)", #tl_var.decls, #tl_var.values)
                end

                local vars = {}
                local exps = {}
                for i = 1, #tl_var.decls do
                    local decl = tl_var.decls[i]
                    local exp = tl_var.values[i]
                    local name = decl.name
                    local typ
                    typ, exp = toplevel_fun_checker:check_initializer_exp(
                                    decl, exp,
                                    "declaration of module variable %s", name)
                    local _ = self:add_global(name, typ)
                    local var = ast.Var.Name(loc, name)
                    toplevel_fun_checker:check_var(var)
                    table.insert(vars, var)
                    table.insert(exps, exp)
                end
                table.insert(toplevel_stats, ast.Stat.Assign(loc, vars, exps))
            end

        elseif group_kind == "Func" then

            local delayed_checks = {}

            for _, tl_func in ipairs(tl_group) do
                local loc = tl_func.loc
                local func_name = tl_func.decl.name
                local func_typ  = self:from_ast_type(tl_func.decl.type)
                local func_lambda = tl_func.value

                local f_id = self:add_function(
                    loc,
                    func_name,
                    func_typ,
                    func_lambda.body)

                if not tl_func.is_local then
                    ir.add_export(self.module, f_id)
                end

                table.insert(delayed_checks, function()
                    local fun_checker = FunChecker.new(self, f_id)
                    fun_checker:check_function(func_lambda, func_typ)
                end)

            end

            for _, check in ipairs(delayed_checks) do
                check()
            end

        elseif group_kind == "Type" then

            -- TODO: Implement recursive and mutually recursive types
            for _, tl_node in ipairs(tl_group) do
                local tag = tl_node._tag
                if     tag == "ast.Toplevel.Typealias" then
                    local name = tl_node.name
                    local typ = self:from_ast_type(tl_node.type)
                    self.symbol_table:add_symbol(name, checker.Name.Type(typ))

                elseif tag == "ast.Toplevel.Record" then
                    local name = tl_node.name
                    local field_names = {}
                    local field_types = {}
                    for _, field_decl in ipairs(tl_node.field_decls) do
                        local field_name = field_decl.name
                        local typ = self:from_ast_type(field_decl.type)
                        table.insert(field_names, field_name)
                        field_types[field_name] = typ
                    end

                    local typ = types.T.Record(name, field_names, field_types)
                    self:add_record_type(name, typ)

                else
                    error("impossible")
                end
            end

        else
            error("impossible")
        end
    end

    return self.module
end

FunChecker = util.Class()
function FunChecker:init(p, f_id)
    self.p = p  -- Checker
    self.f_id = f_id
    self.func = self.p.module.functions[f_id]
end

function FunChecker:add_local(name, typ)
    local l_id = ir.add_local(self.func, name, typ)
    self.p.symbol_table:add_symbol(name, checker.Name.Local(l_id))
    return l_id
end

function FunChecker:check_function(lambda, func_typ)
    assert(lambda._tag == "ast.Exp.Lambda")

    do
        local names = {}
        for _, name in ipairs(lambda.arg_names) do
            if names[name] then
                scope_error(lambda.loc,
                    "function has multiple parameters named '%s'", name)
            end
            names[name] = true
        end
    end

    self.p.symbol_table:with_block(function()
        for i, typ in ipairs(func_typ.arg_types) do
            local name = lambda.arg_names[i]
            self:add_local(name, typ)
        end
        local body = self.func.body
        self:check_stat(body)
    end)
end

function FunChecker:check_and_declare_var(decl, exp)
    local typ
    typ, exp = self:check_initializer_exp(decl,
        exp, "declaration of local variable %s",
        decl.name)
    self:add_local(decl.name, typ)
    decl._name = self.p.symbol_table:find_symbol(decl.name)
    return exp
end

function FunChecker:check_stat(stat)
    local tag = stat._tag
    if     tag == "ast.Stat.Decl" then
        if #stat.exps == 0 then
            for i = 1, #stat.decls do
                local decl = stat.decls[i]
                stat.exps[i] = self:check_and_declare_var(decl, stat.exps[i])
            end
        else
            local nlast_exp = #stat.exps
            local last_exp = stat.exps[nlast_exp]
            for i = 1, #stat.exps do
                local decl = stat.decls[i]
                if decl then
                    stat.exps[i] = self:check_and_declare_var(decl,
                                        stat.exps[i])
                end
            end
            if last_exp and last_exp._types then
                for i = 2, #last_exp._types do
                    local decl = stat.decls[nlast_exp + i - 1]
                    local exp = ast.Exp.ExtraRet(last_exp.loc, last_exp, i,
                                    #last_exp._types)
                    exp._type = last_exp._types[i]
                    if decl then
                        exp = self:check_and_declare_var(decl, exp)
                    end
                    table.insert(stat.exps, exp)
                end
            end
            if #stat.decls ~= #stat.exps then
                type_error(stat.loc,
                    "left-hand side expects %d value(s) but right-hand " ..
                    "side produces %d value(s)", #stat.decls, #stat.exps)
            end
        end

    elseif tag == "ast.Stat.Block" then
        self.p.symbol_table:with_block(function()
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
        self.p.symbol_table:with_block(function()
            for _, inner_stat in ipairs(stat.block.stats) do
                self:check_stat(inner_stat)
            end
            stat.condition = self:check_exp_synthesize(stat.condition)
            check_type_is_condition(stat.condition, "repeat-until loop condition")
        end)

    elseif tag == "ast.Stat.For" then

        local loop_type
        loop_type, stat.start = self:check_initializer_exp(stat.decl, stat.start,
            "numeric for-loop initializer")

        if  loop_type._tag ~= "types.T.Integer" and
            loop_type._tag ~= "types.T.Float"
        then
            type_error(stat.decl.loc,
                "expected integer or float but found %s in for-loop control variable '%s'",
                types.tostring(loop_type),
                stat.decl.name)
        end

        stat.limit = self:check_exp_verify(stat.limit, loop_type,
            "numeric for-loop limit")

        if stat.step then
            stat.step = self:check_exp_verify(stat.step, loop_type,
                "numeric for-loop step")
        else
            local def_step
            if     loop_type._tag == "types.T.Integer" then
                def_step = ast.Exp.Integer(stat.limit.loc, 1)
            elseif loop_type._tag == "types.T.Float" then
                def_step = ast.Exp.Float(stat.limit.loc, 1.0)
            else
                error("impossible")
            end
            stat.step = self:check_exp_synthesize(def_step)
        end

        self.p.symbol_table:with_block(function()
            self:add_local(stat.decl.name, loop_type)
            stat.decl._name = self.p.symbol_table:find_symbol(stat.decl.name)
            self:check_stat(stat.block)
        end)

    elseif tag == "ast.Stat.Assign" then
        local last_exp = stat.exps[#stat.exps]
        if last_exp._tag == "ast.Exp.CallFunc" then
            last_exp = self:check_exp_synthesize(last_exp)
            if last_exp._types and #last_exp._types > 1 then
                for i = 2, #last_exp._types do
                    local nexp = ast.Exp.ExtraRet(last_exp.loc, last_exp, i,
                                    #last_exp._types)
                    nexp._type = last_exp._types[i]
                    table.insert(stat.exps, nexp)
                end
            end
            if #stat.vars ~= #stat.exps then
                type_error(stat.loc,
                    "left-hand side expects %d value(s) but right-hand " ..
                    "side produces %d value(s)", #stat.vars, #stat.exps)
            end
        end
        for i = 1, #stat.vars do
            self:check_var(stat.vars[i])
            stat.exps[i] = self:check_exp_verify(stat.exps[i],
                stat.vars[i]._type, "assignment")
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
        end

    elseif tag == "ast.Stat.Call" then
        stat.call_exp = self:check_exp_synthesize(stat.call_exp)

    elseif tag == "ast.Stat.Return" then
        local ret_types = self.func.typ.ret_types
        local nlast_exp = #stat.exps
        local last_exp = stat.exps[nlast_exp]
        if last_exp and last_exp._tag == "ast.Exp.CallFunc" then
            last_exp = self:check_exp_synthesize(last_exp)
            if last_exp._types and #last_exp._types > 1 then
                for i = 2, #last_exp._types do
                    local nexp = ast.Exp.ExtraRet(last_exp.loc, last_exp, i,
                                    #last_exp._types)
                    nexp._type = last_exp._types[i]
                    table.insert(stat.exps, nexp)
                end
            end
        end
        if #stat.exps ~= #ret_types then
            type_error(stat.loc,
                "returning %d value(s) but function expects %s",
                #stat.exps, #ret_types)
        end

        for i = 1, #stat.exps do
            if stat.exps[i]._tag == "ast.Exp.CallFunc" or
               stat.exps[i]._tag == "ast.Exp.CallMethod" and
               i ~= #stat.exps
            then
                stat.exps[i]._single_ret = true
            end
            stat.exps[i] = self:check_exp_verify(
                stat.exps[i], ret_types[i],
                "return statement")
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

function FunChecker:check_var(var)
    local tag = var._tag
    if     tag == "ast.Var.Name" then
        local cname = self.p.symbol_table:find_symbol(var.name)
        if not cname then
            scope_error(var.loc, "variable '%s' is not declared", var.name)
        end
        var._name = cname

        if     cname._tag == "checker.Name.Type" then
            type_error(var.loc, "'%s' isn't a value", var.name)
        elseif cname._tag == "checker.Name.Local" then
            var._type = self.func.vars[cname.id].typ
        elseif cname._tag == "checker.Name.Global" then
            var._type = self.p.module.globals[cname.id].typ
        elseif cname._tag == "checker.Name.Function" then
            var._type = self.p.module.functions[cname.id].typ
        elseif cname._tag == "checker.Name.Builtin" then
            var._type = builtins[cname.name].typ
               else
            error("impossible")
        end

    elseif tag == "ast.Var.Dot" then
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

    elseif tag == "ast.Var.Bracket" then
        var.t = self:check_exp_synthesize(var.t)
        local arr_type = var.t._type
        if arr_type._tag ~= "types.T.Array" then
            type_error(var.t.loc,
                "expected array but found %s in array indexing",
                types.tostring(arr_type))
        end
        var.k = self:check_exp_verify(
            var.k, types.T.Integer(),
            "array indexing")
        var._type = arr_type.elem

    else
        error("impossible")
    end
end

local function is_numeric_type(typ)
    return typ._tag == "types.T.Integer" or typ._tag == "types.T.Float"
end

function FunChecker:coerce_numeric_exp_to_float(exp)
    local tag = exp._type._tag
    if     tag == "types.T.Float" then
        return exp
    elseif tag == "types.T.Integer" then
        local loc = exp.loc
        return self:check_exp_synthesize(
            ast.Exp.CallFunc(loc,
                ast.Exp.Var(loc,
                    ast.Var.Name(loc, "$tofloat")),
                {exp})
        )
    else
        error("impossible")
    end
end

-- Infers the type of expression @exp, ignoring the surrounding type context
-- Returns the typechecked expression. This may be either be the original
-- expression, or an inner expression if we are dropping a redundant
-- type conversion.
function FunChecker:check_exp_synthesize(exp)
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
        type_error(exp.loc,
            "missing type hint for initializer")

    elseif tag == "ast.Exp.Lambda" then
        type_error(exp.loc,
            "missing type hint for lambda")

    elseif tag == "ast.Exp.Var" then
        self:check_var(exp.var)
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
                    "cannot concatenate with %s value", types.tostring(t))
            end
        end
        exp._type = types.T.String()

    elseif tag == "ast.Exp.Binop" then
        exp.lhs = self:check_exp_synthesize(exp.lhs); local t1 = exp.lhs._type
        exp.rhs = self:check_exp_synthesize(exp.rhs); local t2 = exp.rhs._type
        local op = exp.op
        if op == "==" or op == "~=" then
            if (t1._tag == "types.T.Integer" and t2._tag == "types.T.Float") or
               (t1._tag == "types.T.Float"   and t2._tag == "types.T.Integer") then
                type_error(exp.loc,
                    "comparisons between float and integers are not yet implemented")
                -- note: use Lua's implementation of comparison, don't just cast to float
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
                -- note: use Lua's implementation of comparison, don't just cast to float
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

        if f_type._tag == "types.T.Function" then
            local last_arg = exp.args[#exp.args]
            for i = 1, #exp.args do
                if f_type.arg_types[i] then
                    exp.args[i] = self:check_exp_verify(exp.args[i],
                                    f_type.arg_types[i],
                                    "argument %d of call to function", i)
                else
                    type_error(exp.loc,
                        "function expects %d argument(s) but received %d",
                        #f_type.arg_types, #exp.args)
                end
            end
            if last_arg and last_arg._types then
                for i = 2, #last_arg._types do
                    local narg = #f_type.arg_types - i + 1
                    local param_type = f_type.arg_types[narg]
                    local extra_exp = ast.Exp.ExtraRet(last_arg.loc, last_arg,
                                            i, #last_arg._types)
                    extra_exp._type = last_arg._types[i]
                    if param_type then
                        extra_exp = self:check_exp_verify(extra_exp, param_type,
                                        "argument %d of call to function", i)
                        table.insert(exp.args, extra_exp)
                    else
                        type_error(exp.loc,
                            "function expects %d argument(s) but received %d",
                            #f_type.arg_types, #exp.args)
                    end
                end

            end

            if #f_type.arg_types ~= #exp.args then
                type_error(exp.loc,
                    "function expects %d argument(s) but received %d",
                    #f_type.arg_types, #exp.args)
            end

            if #f_type.ret_types == 1 or
               (#f_type.ret_types > 1 and exp._single_ret)
            then
                exp._type = f_type.ret_types[1]

            elseif #f_type.ret_types > 1 and not exp._single_ret then
                exp._type  = f_type.ret_types[1]
                exp._types = f_type.ret_types

            else
                exp._type = types.T.Void()
            end
        else
            type_error(exp.loc,
                "attempting to call a %s value",
                types.tostring(exp.exp._type))
        end

    elseif tag == "ast.Exp.CallMethod" then
        error("not implemented")

    elseif tag == "ast.Exp.Cast" then
        local dst_t = self.p:from_ast_type(exp.target)
        return self:check_exp_verify(exp.exp, dst_t, "cast expression")

    elseif tag == "ast.Exp.Paren" then
        if exp.exp._tag == "ast.Exp.CallFunc" or
           exp.exp._tag == "ast.Exp.CallMethod"
        then
            exp.exp._single_ret = true
        end
        exp.exp = self:check_exp_synthesize(exp.exp)
        exp._type = exp.exp._type

    elseif tag == "ast.Exp.ExtraRet" then
        -- Fallthrough

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
function FunChecker:check_exp_verify(exp, expected_type, errmsg_fmt, ...)
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
        error("not implemented yet")

    elseif tag == "ast.Exp.Paren" then
        if exp.exp._tag == "ast.Exp.CallFunc" or
           exp.exp._tag == "ast.Exp.CallMethod"
        then
            exp.exp._single_ret = true
        end
        exp.exp = self:check_exp_verify(exp.exp, expected_type, errmsg_fmt, ...)
        return exp

    else

        exp = self:check_exp_synthesize(exp)
        local found_type = exp._type
        if types.equals(found_type, expected_type) then
            return exp
        elseif types.consistent(found_type, expected_type) then
            local cast = ast.Exp.Cast(exp.loc, exp, false)
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

-- Checks `x : ast_typ = exp`, where ast_typ my be optional
function FunChecker:check_initializer_exp(decl, exp, err_fmt, ...)
    if decl.type then
        local typ = self.p:from_ast_type(decl.type)
        if exp then
            return typ, self:check_exp_verify(exp, typ, err_fmt, ...)
        else
            return typ, false
        end
    else
        if exp then
            local e = self:check_exp_synthesize(exp)
            return e._type, e
        else
            type_error(decl.loc, string.format(
                "uninitialized variable '%s' needs a type annotation",
                decl.name))
        end
    end
end


return checker
