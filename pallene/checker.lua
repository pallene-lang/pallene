local ast = require "pallene.ast"
local builtins = require "pallene.builtins"
local ir = require "pallene.ir"
local location = require "pallene.location"
local symtab = require "pallene.symtab"
local types = require "pallene.types"
local typedecl = require "pallene.typedecl"

local checker = {}

--
--
--

local function declare_type(type_name, cons)
    typedecl.declare(checker, "checker", type_name, cons)
end

declare_type("Name", {
    Type     = {"typ"},
    Local    = {"id"},
    Function = {"id"},
    Builtin  = {"name"},
})

--
-- Typecheck
--

local check_program
local check_stat
local check_var
local check_exp_synthesize
local check_exp_verify

-- Type-check a Pallene module
-- On success, returns the typechecked module for the program
-- On failure, returns false and a list of compilation errors
function checker.check(prog_ast)
    local co = coroutine.create(check_program)
    local ok, value = coroutine.resume(co, prog_ast)
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

--
-- Typechecking context
--
-- This gathers all the information that we need in a single table.
-- When typechecking the toplevel, func is false.
-- When typechecking a function, func is the corresponding ir.Func
--

local function Context(module, func, symbol_table)
    return {
        module = module,
        func = func,
        symbol_table = symbol_table,
    }
end

local function add_record_type(ctx, name, typ)
    local _ = ir.add_record_type(ctx.module, typ)
    ctx.symbol_table:add_symbol(name, checker.Name.Type(typ))
    return typ
end

local function add_function(ctx, name, typ)
    local f_id = ir.add_function(ctx.module, name, typ)
    ctx.symbol_table:add_symbol(name, checker.Name.Function(f_id))
    return f_id
end

local function add_local(ctx, name, typ)
    local l_id = ir.add_local(ctx.func, typ, name)
    ctx.symbol_table:add_symbol(name, checker.Name.Local(l_id))
    return l_id
end

--
-- Helper functions
--

local function from_ast_type(ctx, typ)
    local tag = typ._tag
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

    elseif tag == "ast.Type.Value" then
        return types.T.Value()

    elseif tag == "ast.Type.Name" then
        local name = typ.name
        local cname = ctx.symbol_table:find_symbol(typ.name)
        if not cname then
            scope_error(typ.loc,  "type '%s' is not declared", name)
        end
        if cname._tag ~= "checker.Name.Type" then
            type_error(typ.loc, "'%s' isn't a type", name)
        end
        return cname.typ

    elseif tag == "ast.Type.Array" then
        local subtype = from_ast_type(ctx, typ.subtype)
        if subtype._tag == "types.T.Nil" then
            type_error(typ.loc, "array of nil is not allowed")
        end
        return types.T.Array(subtype)

    elseif tag == "ast.Type.Function" then
        if #typ.ret_types >= 2 then
            error("functions with 2+ return values are not yet implemented")
        end
        local p_types = {}
        for _, p_type in ipairs(typ.arg_types) do
            table.insert(p_types, from_ast_type(ctx, p_type))
        end
        local ret_types = {}
        for _, ret_type in ipairs(typ.ret_types) do
            table.insert(ret_types, from_ast_type(ctx, ret_type))
        end
        return types.T.Function(p_types, ret_types)

    else
        error("impossible")
    end
end

local function is_numeric_type(typ)
    return typ._tag == "types.T.Integer" or typ._tag == "types.T.Float"
end

local function coerce_numeric_exp_to_float(ctx, exp)
    local tag = exp._type._tag
    if     tag == "types.T.Float" then
        return exp
    elseif tag == "types.T.Integer" then
        local loc = exp.loc
        return check_exp_synthesize(ctx,
            ast.Exp.CallFunc(loc,
                ast.Exp.Var(loc,
                    ast.Var.Name(loc, checker.Name.Builtin("tofloat"))),
                {exp})
        )
    else
        error("impossible")
    end
end

-- Checks  `x : ast_typ = exp`, with an optional ast_typ
local function check_initializer(ctx, exp, ast_typ, err_fmt, ...)
    if ast_typ then
        local typ = from_ast_type(ctx, ast_typ)
        return check_exp_verify(ctx, exp, typ, err_fmt, ...)
    else
        return check_exp_synthesize(ctx, exp)
    end
end

-- Does this statement always call "return"?
local function stat_always_returns(stat)
    local tag = stat._tag
    if     tag == "ast.Stat.Decl" then
        return false
    elseif tag == "ast.Stat.Block" then
        for _, inner_stat in ipairs(stat.stats) do
            if stat_always_returns(inner_stat) then
                return true
            end
        end
        return false
    elseif tag == "ast.Stat.While" then
        return false
    elseif tag == "ast.Stat.Repeat" then
        return false
    elseif tag == "ast.Stat.For" then
        return false
    elseif tag == "ast.Stat.Assign" then
        return false
    elseif tag == "ast.Stat.Call"  then
        return false
    elseif tag == "ast.Stat.Return" then
        return true
    elseif tag == "ast.Stat.If" then
        return stat_always_returns(stat.then_) and
                stat_always_returns(stat.else_)
    else
        error("impossible")
    end
end

--
-- Typecheck (cont.)
--

check_program = function(prog_ast)

    do
        -- Forbid duplicates
        local names = {}
        for _, tl_node in ipairs(prog_ast) do
            local name = ast.toplevel_name(tl_node)
            local loc = tl_node.loc
            local old_loc = names[name]
            if old_loc then
                scope_error(loc,
                    "duplicate toplevel declaration for %s, previous one at line %d",
                    name, old_loc.line)
            end
            names[name] = loc
        end
    end

    local module = ir.Module()
    local symbol_table = symtab.new()
    local ctx = Context(module, false, symbol_table)
    ctx.symbol_table:with_block(function()

        -- Add builtins to symbol table.
        for name, _ in pairs(builtins) do
            -- This order is not deterministic but that is OK because
            -- there is no risk of one builtin shadowing another.
            ctx.symbol_table:add_symbol(name, checker.Name.Builtin(name))
        end

        -- Check toplevel

        for _, tl_node in ipairs(prog_ast) do
            local tag = tl_node._tag
            if     tag == "ast.Toplevel.Import" then
                type_error(tl_node.loc, "modules are not implemented yet")

            elseif tag == "ast.Toplevel.Var" then
                type_error(tl_node.loc, "toplevel variables are not implemented")

            elseif tag == "ast.Toplevel.Func" then
                local n_arg = #tl_node.params
                local n_ret = #tl_node.ret_types

                local param_names = {}
                local param_types = {}
                for i = 1, n_arg do
                    local decl = tl_node.params[i]
                    param_names[i] = decl.name
                    param_types[i] = from_ast_type(ctx, decl.type)
                end

                local ret_types = {}
                for i = 1, n_ret do
                    ret_types[i] = from_ast_type(ctx, tl_node.ret_types[i])
                end
                local func_typ = types.T.Function(param_types, ret_types)

                if #ret_types >= 2 then
                    error("functions with 2+ return values are not yet implemented")
                end

                do
                    local names = {}
                    for _, name in ipairs(param_names) do
                        if names[name] then
                            scope_error(tl_node.loc,
                                "function '%s' has multiple parameters named '%s'",
                                tl_node.name, name)
                        end
                        names[name] = true
                    end
                end

                -- Generate function body

                local f_id = add_function(ctx, tl_node.name, func_typ)
                local func = module.functions[f_id]
                local func_ctx = Context(module, func, symbol_table)

                if tl_node.is_local then
                    ir.add_export(module, f_id)
                end

                symbol_table:with_block(function()
                    for i = 1, #param_types do
                        add_local(func_ctx, param_names[i], param_types[i])
                    end
                    func.body = check_stat(func_ctx, tl_node.block, ret_types)
                end)

                if #ret_types > 0 and not stat_always_returns(func.body) then
                    type_error(tl_node.loc,
                        "control reaches end of function with non-empty return type")
                end

            elseif tag == "ast.Toplevel.Record" then
                local name = tl_node.name
                local field_names = {}
                local field_types = {}
                for _, field_decl in ipairs(tl_node.field_decls) do
                    local field_name = field_decl.name
                    local typ = from_ast_type(ctx, field_decl.type)
                    table.insert(field_names, field_name)
                    field_types[field_name] = typ
                end

                local typ = types.T.Record(name, field_names, field_types)
                add_record_type(ctx, name, typ)

            else
                error("impossible")
            end
        end

    end)

    return module
end

check_stat = function(ctx, stat, ret_types)
    local tag = stat._tag
    if     tag == "ast.Stat.Decl" then
        stat.exp = check_initializer(ctx, stat.exp, stat.decl.type,
            "declaration of local variable %s", stat.decl.name)
        add_local(ctx, stat.decl.name, stat.exp._type)
        stat.decl._name = ctx.symbol_table:find_symbol(stat.decl.name)

    elseif tag == "ast.Stat.Block" then
        ctx.symbol_table:with_block(function()
            for _, inner_stat in ipairs(stat.stats) do
                check_stat(ctx, inner_stat, ret_types)
            end
        end)

    elseif tag == "ast.Stat.While" then
        stat.condition = check_exp_verify(ctx,
            stat.condition, types.T.Boolean(),
            "while loop condition")
        check_stat(ctx, stat.block, ret_types)

    elseif tag == "ast.Stat.Repeat" then
        assert(stat.block._tag == "ast.Stat.Block")
        ctx.symbol_table:with_block(function()
            for _, inner_stat in ipairs(stat.block.stats) do
                check_stat(ctx, inner_stat, ret_types)
            end
            stat.condition = check_exp_verify(ctx,
                stat.condition, types.T.Boolean(),
                "repeat-until loop condition")
        end)

    elseif tag == "ast.Stat.For" then

        stat.start = check_initializer(ctx, stat.start, stat.decl.type,
            "numeric for-loop initializer")
        local loop_type = stat.start._type

        if  loop_type._tag ~= "types.T.Integer" and
            loop_type._tag ~= "types.T.Float"
        then
            type_error(stat.decl.loc,
                "expected integer or float but found %s in for-loop control variable '%s'",
                types.tostring(loop_type),
                stat.decl.name)
        end

        stat.limit = check_exp_verify(ctx, stat.limit, loop_type,
            "numeric for-loop limit")

        if stat.step then
            stat.step = check_exp_verify(ctx, stat.step, loop_type,
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
            stat.step = check_exp_synthesize(ctx, def_step)
        end

        ctx.symbol_table:with_block(function()
            add_local(ctx, stat.decl.name, loop_type)
            stat.decl._name = ctx.symbol_table:find_symbol(stat.decl.name)
            check_stat(ctx, stat.block, ret_types)
        end)

    elseif tag == "ast.Stat.Assign" then
        check_var(ctx, stat.var)
        stat.exp = check_exp_verify(ctx, stat.exp, stat.var._type, "assignment")
        if stat.var._tag == "ast.Var.Name" then
            local ntag = stat.var._name._tag
            if ntag == "checker.Name.Function" then
                type_error(stat.loc,
                    "attempting to assign to toplevel constant function %s",
                    stat.var.name)
            elseif ntag == "checker.Name.Builtin" then
                type_error(stat.loc,
                    "attempting to assign to builtin function %s",
                    stat.var.name)
            end
        end

    elseif tag == "ast.Stat.Call" then
        stat.call_exp = check_exp_synthesize(ctx, stat.call_exp)

    elseif tag == "ast.Stat.Return" then
        assert(#ret_types <= 1)
        if #stat.exps ~= #ret_types then
            type_error(stat.loc,
                "returning %d value(s) but function expects %s",
                #stat.exps, #ret_types)
        end

        for i = 1, #stat.exps do
            stat.exps[i] = check_exp_verify(ctx,
                stat.exps[i], ret_types[i],
                "return statement")
        end

    elseif tag == "ast.Stat.If" then
        stat.condition = check_exp_verify(ctx,
            stat.condition, types.T.Boolean(),
            "if statement condition")
        check_stat(ctx, stat.then_, ret_types)
        check_stat(ctx, stat.else_, ret_types)

    else
        error("impossible")
    end

    return stat
end

check_var = function(ctx, var)
    local tag = var._tag
    if     tag == "ast.Var.Name" then
        local cname = ctx.symbol_table:find_symbol(var.name)
        if not cname then
            scope_error(var.loc, "variable '%s' is not declared", var.name)
        end
        var._name = cname

        if cname._tag == "checker.Name.Local" then
            var._type = ctx.func.vars[cname.id].typ
        elseif cname._tag == "checker.Name.Function" then
            var._type = ctx.module.functions[cname.id].typ
        elseif cname._tag == "checker.Name.Builtin" then
            var._type = builtins[cname.name].typ
        else
            type_error(var.loc, "'%s' isn't a value", var.name)
        end

    elseif tag == "ast.Var.Dot" then
        var.exp = check_exp_synthesize(ctx, var.exp)
        local rec_type = var.exp._type
        if rec_type._tag ~= "types.T.Record" then
            type_error(var.loc,
                "trying to access a member of value of type '%s'",
                types.tostring(rec_type))
        end
        local field_type = rec_type.field_types[var.name]
        if not field_type then
            type_error(var.loc,
                "field '%s' not found in record '%s'",
                var.name, types.tostring(rec_type))
        end
        var._type = field_type

    elseif tag == "ast.Var.Bracket" then
        var.t = check_exp_synthesize(ctx, var.t)
        local arr_type = var.t._type
        if arr_type._tag ~= "types.T.Array" then
            type_error(var.t.loc,
                "expected array but found %s in array indexing",
                types.tostring(arr_type))
        end
        var.k = check_exp_verify(ctx,
            var.k, types.T.Integer(),
            "array indexing")
        var._type = arr_type.elem

    else
        error("impossible")
    end
end


-- Infers the type of expression @exp
-- Returns the typechecked expression. This may be either be the original
-- expression, or an inner expression if we are dropping a redundant
-- type conversion.
--
-- Returns nothing
check_exp_synthesize = function(ctx, exp)
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
            "missing type hint for array or record initializer")

    elseif tag == "ast.Exp.Var" then
        check_var(ctx, exp.var)
        exp._type = exp.var._type

    elseif tag == "ast.Exp.Unop" then
        exp.exp = check_exp_synthesize(ctx, exp.exp)
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
            if t._tag ~= "types.T.Boolean" then
                -- We are being intentionaly restrictive here w.r.t Lua
                type_error(exp.loc,
                    "trying to boolean negate a %s instead of a boolean",
                    types.tostring(t))
            end
            exp._type = types.T.Boolean()
        else
            error("impossible")
        end

    elseif tag == "ast.Exp.Concat" then
        for _, inner_exp in ipairs(exp.exps) do
            inner_exp = check_exp_synthesize(ctx, inner_exp)
            local t = inner_exp._type
            if t._tag ~= "types.T.String" then
                type_error(inner_exp.loc,
                    "cannot concatenate with %s value", types.tostring(t))
            end
        end
        exp._type = types.T.String()

    elseif tag == "ast.Exp.Binop" then
        exp.lhs = check_exp_synthesize(ctx, exp.lhs); local t1 = exp.lhs._type
        exp.rhs = check_exp_synthesize(ctx, exp.rhs); local t2 = exp.rhs._type
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
                exp.lhs = coerce_numeric_exp_to_float(ctx, exp.lhs)
                exp.rhs = coerce_numeric_exp_to_float(ctx, exp.rhs)
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

            exp.lhs = coerce_numeric_exp_to_float(ctx, exp.lhs)
            exp.rhs = coerce_numeric_exp_to_float(ctx, exp.rhs)
            exp._type = types.T.Float()

        elseif op == "and" or op == "or" then
            if t1._tag ~= "types.T.Boolean" then
                type_error(exp.loc,
                    "left hand side of logical expression is a %s instead of a boolean",
                    types.tostring(t1))
            end
            if t2._tag ~= "types.T.Boolean" then
                type_error(exp.loc,
                    "right hand side of logical expression is a %s instead of a boolean",
                    types.tostring(t2))
            end
            exp._type = types.T.Boolean()

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
        exp.exp = check_exp_synthesize(ctx, exp.exp)
        local f_type = exp.exp._type

        if f_type._tag == "types.T.Function" then
            if #f_type.params ~= #exp.args then
                type_error(exp.loc,
                    "function expects %d argument(s) but received %d",
                    #f_type.params, #exp.args)
            end
            for i = 1, math.min(#f_type.params, #exp.args) do
                exp.args[i] = check_exp_verify(ctx,
                    exp.args[i], f_type.params[i],
                    "argument %d of call to function", i)
            end
            assert(#f_type.ret_types <= 1)
            if #f_type.ret_types >= 1 then
                exp._type = f_type.ret_types[1]
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
        local dst_t = from_ast_type(ctx, exp.target)
        return check_exp_verify(ctx, exp.exp, dst_t, "cast expression")

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
-- errmsg_fmt: format string describing what part of the program is
--             responsible for this type check
-- ...: arguments to the "errmsg_fmt" format string
check_exp_verify = function(ctx, exp, expected_type, errmsg_fmt, ...)
    local tag = exp._tag
    if tag == "ast.Exp.Initlist" then

        if expected_type._tag == "types.T.Array" then
            for _, field in ipairs(exp.fields) do
                if field.name then
                    type_error(field.loc,
                        "named field %s in array initializer",
                        field.name)
                end
                field.exp = check_exp_verify(ctx,
                    field.exp, expected_type.elem,
                    "array initializer")
            end

        elseif expected_type._tag == "types.T.Record" then
            local initialized_fields = {}
            for _, field in ipairs(exp.fields) do
                if not field.name then
                    type_error(field.loc,
                        "record initializer has array part")
                end

                if initialized_fields[field.name] then
                    type_error(field.loc,
                        "duplicate field %s in record initializer",
                        field.name)
                end
                initialized_fields[field.name] = true

                local field_type = expected_type.field_types[field.name]
                if not field_type then
                    type_error(field.loc,
                        "invalid field %s in record initializer for %s",
                        field.name, types.tostring(expected_type))
                end

                field.exp = check_exp_verify(ctx,
                    field.exp, field_type,
                    "record initializer")
            end

            for field_name, _ in pairs(expected_type.field_types) do
                if not initialized_fields[field_name] then
                    type_error(exp.loc,
                        "required field %s is missing from initializer",
                        field_name)
                end
            end
        else
            type_error(exp.loc,
                "type hint for array or record initializer is not an array or record type")
        end

        exp._type = expected_type
        return exp

    else

        exp = check_exp_synthesize(ctx, exp)
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

return checker
