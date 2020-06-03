-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local ir = require "pallene.ir"
local types = require "pallene.types"
local util = require "pallene.util"
local typedecl = require "pallene.typedecl"

local to_ir = {}

typedecl.declare(to_ir, "to_ir", "LHS", {
    Local  = {"id"},
    Global = {"id"},
    Array  = {"typ", "arr", "i"},
    Table  = {"typ", "t", "field"},
    Record = {"typ", "rec", "field"},
})

local ToIR -- forward declaration

function to_ir.convert(module)
    for _, func in ipairs(module.functions) do
        local cmds = {}
        ToIR.new(module, func):convert_stat(cmds, func.body)
        func.body = ir.Cmd.Seq(cmds)
    end
    ir.clean_all(module)
    return module, {}
end

--
--
--

ToIR = util.Class()
function ToIR:init(module, func)
    self.module = module
    self.func = func
    self.dsts_of_call = {} -- { ast.Exp => { var_id } }
end

function ToIR:convert_stats(cmds, stats)
    for i = 1, #stats do
        self:convert_stat(cmds, stats[i])
    end
end

-- Converts a typechecked ast.Stat into a list of ir.Cmd
-- The converted ir.Cmd nodes are appended to the @cmds list
function ToIR:convert_stat(cmds, stat)
    local tag = stat._tag
    if     tag == "ast.Stat.Block" then
        self:convert_stats(cmds, stat.stats)

    elseif tag == "ast.Stat.While" then
        local body = {}
        local cond     = self:exp_to_value(body, stat.condition)
        local condBool = self:value_is_truthy(body, stat.condition, cond)
        table.insert(body, ir.Cmd.If(stat.loc, condBool, ir.Cmd.Nop(), ir.Cmd.Break()))
        self:convert_stat(body, stat.block)
        table.insert(cmds, ir.Cmd.Loop(ir.Cmd.Seq(body)))

    elseif tag == "ast.Stat.Repeat" then
        local body = {}
        self:convert_stat(body, stat.block)
        local cond     = self:exp_to_value(body, stat.condition)
        local condBool = self:value_is_truthy(body, stat.condition, cond)
        table.insert(body, ir.Cmd.If(stat.loc, condBool, ir.Cmd.Break(), ir.Cmd.Nop()))
        table.insert(cmds, ir.Cmd.Loop(ir.Cmd.Seq(body)))

    elseif tag == "ast.Stat.If" then
        local cond     = self:exp_to_value(cmds, stat.condition)
        local condBool = self:value_is_truthy(cmds, stat.condition, cond)
        local then_ = {}; self:convert_stat(then_, stat.then_)
        local else_ = {}; self:convert_stat(else_, stat.else_)
        table.insert(cmds, ir.Cmd.If(stat.loc, condBool, ir.Cmd.Seq(then_), ir.Cmd.Seq(else_)))

    elseif tag == "ast.Stat.For" then
        local start = self:exp_to_value(cmds, stat.start)
        local limit = self:exp_to_value(cmds, stat.limit)
        local step  = self:exp_to_value(cmds, stat.step)

        local cname = stat.decl._name
        assert(cname._tag == "checker.Name.Local")
        local v = cname.id

        local body = {}
        self:convert_stat(body, stat.block)

        table.insert(cmds, ir.Cmd.For(stat.loc, v, start, limit, step, ir.Cmd.Seq(body)))

    elseif tag == "ast.Stat.Assign" then
        local loc = stat.loc
        local vars = stat.vars
        local exps = stat.exps
        assert(#vars == #exps)

        -- In Lua, the expressions in an assignment are evaluated from left to right and all
        -- sub-expressions are evaluated before the assignments are resolved. Assignments happen
        -- from right to left.

        -- In a multiple assignment we have to be careful if we end up with an ir.Value that refers
        -- to a local variable because that variable can potentially be overwritten in another part
        -- of the the assignment.  When that happens we need to save the value to a temporary
        -- variable before resolving the assignments.
        local function save_if_necessary(exp, i)
            local val = self:exp_to_value(cmds, exp)
            if  val._tag == "ir.Value.LocalVar" then
                for j = i+1, #vars do
                    local var = vars[j]
                    if  var._tag == "ast.Var.Name" and
                        var._name._tag == "checker.Name.Local" and
                        var._name.id == val.id
                    then
                        local v = ir.add_local(self.func, false, exp._type)
                        table.insert(cmds, ir.Cmd.Move(loc, v, val))
                        return ir.Value.LocalVar(v)
                    end
                end
            end
            return val
        end

        local lhss = {}
        for i, var in ipairs(vars) do
            if     var._tag == "ast.Var.Name" then
                local cname = var._name
                if     cname._tag == "checker.Name.Local" then
                    table.insert(lhss, to_ir.LHS.Local(cname.id))
                elseif cname._tag == "checker.Name.Global" then
                    table.insert(lhss, to_ir.LHS.Global(cname.id))
                else
                    error("impossible")
                end

            elseif var._tag == "ast.Var.Bracket" then
                local typ = stat.exps[i]._type
                local t = save_if_necessary(var.t, i)
                local k = save_if_necessary(var.k, i)
                table.insert(lhss, to_ir.LHS.Array(typ, t, k))

            elseif var._tag == "ast.Var.Dot" then
                local t = save_if_necessary(var.exp, i)
                local ttag = var.exp._type._tag
                if     ttag == "types.T.Table" then
                    local typ = stat.exps[i]._type
                    table.insert(lhss, to_ir.LHS.Table(typ, t, var.name))
                elseif ttag == "types.T.Record" then
                    local typ = var.exp._type
                    table.insert(lhss, to_ir.LHS.Record(typ, t, var.name))
                else
                    error("impossible")
                end

            else
                error("impossible")
            end
        end

        -- We'd like to avoid storing the RHS results in temporary variables when possible, to avoid
        -- cluttering the generated code with too many variables. There are three main cases:
        --
        --  1) If the expression is the rightmost one in the RHS then we are free to use
        --  exp_to_assignment because this is also the first assignment to be resolved.
        --  This is always the case for a single assignment.
        --
        -- The other cases are for expressions that are not the rightmost one in the RHS.
        --
        --  2) If the exp is something simple that can be evaluated with exp_to_value then the thing
        --  that we need to worry about is if we are reading from a local variable that is being
        --  assigned to in another part of this multi-assignment. We can take care of this with
        --  save_if_necessary.
        --
        --  3) If the expression is something more complex that expects to be evaluated with
        --  exp_to_assignment then in theory we could use exp_to_assignment if we could prove that
        --  it is safe to write to the destination variables at this point in the program, before
        --  the rest of the RHS has been evaluated. However, we don't bother optimizing this last
        --  case because if the programmer has written a complicated multiple-assignment then it is
        --  likely that it isn't something that could have been written as a sequence of single
        --  assignments. (Our implementation always ends up creating a temporary variable in this
        --  case because save_if_necessary calls exp_to_value.)
        local vals = {}
        for i, exp in ipairs(exps) do
            local is_last = (i == #exps or exps[i+1]._tag == "ast.Exp.ExtraRet")
            if is_last and lhss[i]._tag == "to_ir.LHS.Local" then
                self:exp_to_assignment(cmds, lhss[i].id, exp)
                vals[i] = false
            else
                vals[i] = save_if_necessary(exp, i)
            end
        end

        for i = #stat.vars, 1, -1 do
            local lhs = lhss[i]
            local val = vals[i]
            if val then
                local cmd
                local ltag = lhs._tag
                if     ltag == "to_ir.LHS.Local" then
                    cmd = ir.Cmd.Move(loc, lhs.id, val)
                elseif ltag == "to_ir.LHS.Global" then
                    cmd = ir.Cmd.SetGlobal(loc, lhs.id, val)
                elseif ltag == "to_ir.LHS.Array" then
                    cmd = ir.Cmd.SetArr(loc, lhs.typ, lhs.arr, lhs.i, val)
                elseif ltag == "to_ir.LHS.Table" then
                    local str = ir.Value.String(lhs.field)
                    cmd = ir.Cmd.SetTable(loc, lhs.typ, lhs.t, str, val)
                elseif ltag == "to_ir.LHS.Record" then
                    cmd = ir.Cmd.SetField(loc, lhs.typ, lhs.rec, lhs.field, val)
                else
                    error("impossible")
                end
                table.insert(cmds, cmd)
            end
        end

    elseif tag == "ast.Stat.Decl" then
        for i = 1, #stat.decls do
            if stat.exps[i] then
                local cname = stat.decls[i]._name
                assert(cname._tag == "checker.Name.Local")
                local v = cname.id
                local exp = stat.exps[i]
                self:exp_to_assignment(cmds, v, exp)
            end
        end

    elseif tag == "ast.Stat.Call" then
        self:exp_to_assignment(cmds, false, stat.call_exp)

    elseif tag == "ast.Stat.Return" then
        local vals = {}
        for i, exp in ipairs(stat.exps) do
            vals[i] = self:exp_to_value(cmds, exp)
        end
        table.insert(cmds, ir.Cmd.Return(stat.loc, vals))

    elseif tag == "ast.Stat.Break" then
        table.insert(cmds, ir.Cmd.Break())

    else
        error("impossible")
    end
end

local unops = {
    { "#",   "Array",   "ArrLen"  },
    { "#",   "String",  "StrLen"  },
    { "-",   "Integer", "IntNeg"  },
    { "-",   "Float",   "FltNeg"  },
    { "~",   "Integer", "BitNeg"  },
    { "not", "Boolean", "BoolNot" },
}

local binops = {
    { "+"  , "Integer", "Integer", "IntAdd"  },
    { "-"  , "Integer", "Integer", "IntSub"  },
    { "*"  , "Integer", "Integer", "IntMul"  },
    { "//" , "Integer", "Integer", "IntDivi" },
    { "%"  , "Integer", "Integer", "IntMod"  },

    { "+"  , "Float",   "Float",   "FltAdd"  },
    { "-"  , "Float",   "Float",   "FltSub"  },
    { "*"  , "Float",   "Float",   "FltMul"  },
    { "//" , "Float",   "Float",   "FltDivi" },
    { "%"  , "Float",   "Float",   "FltMod"  },
    { "/"  , "Float",   "Float",   "FltDiv"  },

    { "&" , "Integer", "Integer", "BitAnd"    },
    { "|" , "Integer", "Integer", "BitOr"     },
    { "~" , "Integer", "Integer", "BitXor"    },
    { "<<", "Integer", "Integer", "BitLShift" },
    { ">>", "Integer", "Integer", "BitRShift" },

    { "^" , "Float",   "Float",   "FltPow" },

    { "==", "Any",   "Any",   "AnyEq"  },
    { "~=", "Any",   "Any",   "AnyNeq" },

    { "==", "Nil",     "Nil",     "NilEq"  },
    { "~=", "Nil",     "Nil",     "NilNeq" },

    { "==", "Boolean", "Boolean", "BoolEq"  },
    { "~=", "Boolean", "Boolean", "BoolNeq" },

    { "==", "Integer", "Integer", "IntEq"  },
    { "~=", "Integer", "Integer", "IntNeq" },
    { "<" , "Integer", "Integer", "IntLt"  },
    { ">" , "Integer", "Integer", "IntGt"  },
    { "<=", "Integer", "Integer", "IntLeq" },
    { ">=", "Integer", "Integer", "IntGeq" },

    { "==", "Float",   "Float",   "FltEq"  },
    { "~=", "Float",   "Float",   "FltNeq" },
    { "<" , "Float",   "Float",   "FltLt"  },
    { ">" , "Float",   "Float",   "FltGt"  },
    { "<=", "Float",   "Float",   "FltLeq" },
    { ">=", "Float",   "Float",   "FltGeq" },

    { "==", "String",  "String",   "StrEq"  },
    { "~=", "String",  "String",   "StrNeq" },
    { "<" , "String",  "String",   "StrLt"  },
    { ">" , "String",  "String",   "StrGt"  },
    { "<=", "String",  "String",   "StrLeq" },
    { ">=", "String",  "String",   "StrGeq" },

    { "==", "Function","Function", "FunctionEq"  },
    { "~=", "Function","Function", "FunctionNeq" },

    { "==", "Array",   "Array",    "ArrayEq"    },
    { "~=", "Array",   "Array",    "ArrayNeq"    },

    { "==", "Table",   "Table",    "TableEq"    },
    { "~=", "Table",   "Table",    "TableNeq"    },

    { "==", "Record",  "Record",   "RecordEq",  },
    { "~=", "Record",  "Record",   "RecordNeq",  },
}

local function type_specific_unop(op, typ)
   for _, x in ipairs(unops) do
        local op_, typ_, name = x[1], x[2], x[3]
        if
            op == op_ and
            typ._tag == ("types.T." .. typ_)
        then
            return name
        end
    end
    error("impossible")
end

local function type_specific_binop(op, typ1, typ2)
    for _, x in ipairs(binops) do
        local op_, typ1_, typ2_, name = x[1], x[2], x[3], x[4]
        if
            op == op_ and
            typ1._tag == ("types.T." .. typ1_) and
            typ2._tag == ("types.T." .. typ2_)
        then
            return name
        end
    end
    error("impossible")
end

-- Converts a typechecked ast.Exp to a ir.Value. If necessary, will create a fresh variable, and add
-- intermediate computations to the @cmds list.
function ToIR:exp_to_value(cmds, exp, _recursive)
    local tag = exp._tag
    if     tag == "ast.Exp.Nil" then
        return ir.Value.Nil()

    elseif tag == "ast.Exp.Bool" then
        return ir.Value.Bool(exp.value)

    elseif tag == "ast.Exp.Integer" then
        return ir.Value.Integer(exp.value)

    elseif tag == "ast.Exp.Float" then
        return ir.Value.Float(exp.value)

    elseif tag == "ast.Exp.String" then
        return ir.Value.String(exp.value)

    elseif tag == "ast.Exp.Var" then
        local var = exp.var
        if     var._tag == "ast.Var.Name" then
            local cname = var._name
            if     cname._tag == "checker.Name.Local" then
                return ir.Value.LocalVar(cname.id)

            elseif cname._tag == "checker.Name.Global" then
                -- Fallthrough to default

            elseif cname._tag == "checker.Name.Function" then
                return ir.Value.Function(cname.id)

            elseif cname._tag == "checker.Name.Builtin" then
                error("not implemented")

            else
                error("impossible")
            end
        else
            -- Fallthrough to default
        end

    elseif tag == "ast.Exp.Paren" then
        return self:exp_to_value(cmds, exp.exp)
    end

    if _recursive then
        -- Avoid infinite loop due to type error
        error(string.format(
            "Neither exp_to_value or exp_to_assignment handled tag %q)",
            exp._tag))
    end

    -- Otherwise we need to create a temporary variable
    local v = ir.add_local(self.func, false, exp._type)
    self:exp_to_assignment(cmds, v, exp)
    return ir.Value.LocalVar(v)
end

-- Converts the assignment `dst = exp` into a list of ir.Cmd, which are added to the @cmds list.
-- If this is a function call, then dst may be false
function ToIR:exp_to_assignment(cmds, dst, exp)
    local loc = exp.loc
    local tag = exp._tag

    local use_exp_to_value = false

    if not dst then
        assert(tag == "ast.Exp.CallFunc" or tag == "ast.Exp.CallMethod")
    end

    if     tag == "ast.Exp.Initlist" then
        local typ = exp._type
        if     typ._tag == "types.T.Array" then
            local n = ir.Value.Integer(#exp.fields)
            table.insert(cmds, ir.Cmd.NewArr(loc, dst, n))
            table.insert(cmds, ir.Cmd.CheckGC())
            for i, field in ipairs(exp.fields) do
                local av = ir.Value.LocalVar(dst)
                local iv = ir.Value.Integer(i)
                local vv = self:exp_to_value(cmds, field.exp)
                local src_typ = field.exp._type
                table.insert(cmds, ir.Cmd.SetArr(loc, src_typ, av, iv, vv))
            end

        elseif typ._tag == "types.T.Table" then
            local n = ir.Value.Integer(#exp.fields)
            table.insert(cmds, ir.Cmd.NewTable(loc, dst, n))
            table.insert(cmds, ir.Cmd.CheckGC())
            for _, field in ipairs(exp.fields) do
                local tv = ir.Value.LocalVar(dst)
                local kv = ir.Value.String(field.name)
                local vv = self:exp_to_value(cmds, field.exp)
                local src_typ = field.exp._type
                local cmd = ir.Cmd.SetTable(loc, src_typ, tv, kv, vv)
                table.insert(cmds, cmd)
            end

        elseif typ._tag == "types.T.Record" then
            local field_exps = {}
            for _, field in ipairs(exp.fields) do
                field_exps[field.name] = field.exp
            end

            table.insert(cmds, ir.Cmd.NewRecord(loc, typ, dst))
            table.insert(cmds, ir.Cmd.CheckGC())
            for _, field_name in ipairs(typ.field_names) do
                local f_exp = assert(field_exps[field_name])
                local dv = ir.Value.LocalVar(dst)
                local vv = self:exp_to_value(cmds, f_exp)
                table.insert(cmds, ir.Cmd.SetField(exp.loc, typ, dv, field_name, vv))
            end
        else
            error("impossible")
        end

    elseif tag == "ast.Exp.Lambda" then
        error("not implemented")

    elseif tag == "ast.Exp.ExtraRet" then
        assert(self.dsts_of_call[exp.call_exp])
        self.dsts_of_call[exp.call_exp][exp.i] = dst

    elseif tag == "ast.Exp.CallFunc" then

        local function get_xs()
            -- "xs" should be evaluated after "f"
            local xs = {}
            for i, arg_exp in ipairs(exp.args) do
                xs[i] = self:exp_to_value(cmds, arg_exp)
            end
            return xs
        end

        local f_typ = exp.exp._type
        local cname = (
            exp.exp._tag == "ast.Exp.Var" and
            exp.exp.var._tag == "ast.Var.Name" and
            exp.exp.var._name )

        if     cname and cname._tag == "checker.Name.Function" then
            assert(not self.dsts_of_call[exp])
            self.dsts_of_call[exp] = {}
            self.dsts_of_call[exp][1] = dst
            for i = 2, #exp._types do
                self.dsts_of_call[exp][i] = false
            end
            local xs = get_xs()
            table.insert(cmds, ir.Cmd.CallStatic(loc, f_typ, self.dsts_of_call[exp], cname.id, xs))

        elseif cname and cname._tag == "checker.Name.Builtin" then
            local xs = get_xs()

            local bname = cname.name
            if     bname == "io.write" then
                assert(#xs == 1)
                table.insert(cmds, ir.Cmd.BuiltinIoWrite(loc, xs))
            elseif bname == "math.sqrt" then
                assert(#xs == 1)
                table.insert(cmds, ir.Cmd.BuiltinMathSqrt(loc, {dst}, xs))
            elseif bname == "string_.char" then
                assert(#xs == 1)
                table.insert(cmds, ir.Cmd.BuiltinStringChar(loc, {dst}, xs))
                table.insert(cmds, ir.Cmd.CheckGC())
            elseif bname == "string_.sub" then
                assert(#xs == 3)
                table.insert(cmds,
                    ir.Cmd.BuiltinStringSub(loc, {dst}, xs))
                table.insert(cmds, ir.Cmd.CheckGC())
            elseif bname == "tofloat" then
                assert(#xs == 1)
                table.insert(cmds, ir.Cmd.BuiltinToFloat(loc, {dst}, xs))
            elseif bname == "type" then
                assert(#xs == 1)
                table.insert(cmds, ir.Cmd.BuiltinType(loc, {dst}, xs))
            else
                error("impossible")
            end

        else
            assert(not self.dsts_of_call[exp])
            self.dsts_of_call[exp] = {}
            self.dsts_of_call[exp][1] = dst
            local f = self:exp_to_value(cmds, exp.exp)
            local xs = get_xs()
            table.insert(cmds, ir.Cmd.CallDyn(loc, f_typ, self.dsts_of_call[exp], f, xs))
        end

    elseif tag == "ast.Exp.CallMethod" then
        error("not implemented")

    elseif tag == "ast.Exp.Var" then
        local var = exp.var
        if     var._tag == "ast.Var.Name" then
            local cname = var._name
            if cname._tag == "checker.Name.Global" then
                table.insert(cmds, ir.Cmd.GetGlobal(loc, dst, cname.id))
            else
                use_exp_to_value = true
            end

        elseif var._tag == "ast.Var.Bracket" then
            local arr = self:exp_to_value(cmds, var.t)
            local i   = self:exp_to_value(cmds, var.k)
            local dst_typ = var._type
            table.insert(cmds, ir.Cmd.GetArr(loc, dst_typ, dst, arr, i))

        elseif var._tag == "ast.Var.Dot" then
            local typ = assert(var.exp._type)
            local field = var.name
            local rec = self:exp_to_value(cmds, var.exp)
            local cmd
            if     typ._tag == "types.T.Table" then
                local key = ir.Value.String(field)
                local dst_typ = typ.fields[field]
                cmd = ir.Cmd.GetTable(loc, dst_typ, dst, rec, key)
            elseif typ._tag == "types.T.Record" then
                cmd = ir.Cmd.GetField(loc, typ, dst, rec, field)
            else
                error("impossible")
            end
            table.insert(cmds, cmd)

        else
            error("impossible")
        end

    elseif tag == "ast.Exp.Unop" then
        local op = exp.op
        if op == "not" then
            local e = self:exp_to_value(cmds, exp.exp)
            local v = self:value_is_truthy(cmds, exp.exp, e)
            table.insert(cmds, ir.Cmd.Unop(loc, dst, "BoolNot", v))
        else
            local irop = type_specific_unop(op, exp.exp._type)
            local v = self:exp_to_value(cmds, exp.exp)
            table.insert(cmds, ir.Cmd.Unop(loc, dst, irop, v))
        end

    elseif tag == "ast.Exp.Concat" then
        local xs = {}
        for i, x_exp in ipairs(exp.exps) do
            xs[i] = self:exp_to_value(cmds, x_exp)
        end
        table.insert(cmds, ir.Cmd.Concat(loc, dst, xs))
        table.insert(cmds, ir.Cmd.CheckGC())

    elseif tag == "ast.Exp.Binop" then
        local op = exp.op
        if     op == "and" then
            self:exp_to_assignment(cmds, dst, exp.lhs)
            local v = ir.Value.LocalVar(dst)
            local condBool = self:value_is_truthy(cmds, exp.lhs, v)
            local rhs_cmds = {}
            self:exp_to_assignment(rhs_cmds, dst, exp.rhs)
            table.insert(cmds, ir.Cmd.If(exp.loc,
                condBool,
                ir.Cmd.Seq(rhs_cmds),
                ir.Cmd.Seq({})))

        elseif op == "or" then
            self:exp_to_assignment(cmds, dst, exp.lhs)
            local v = ir.Value.LocalVar(dst)
            local condBool = self:value_is_truthy(cmds, exp.lhs, v)
            local rhs_cmds = {}
            self:exp_to_assignment(rhs_cmds, dst, exp.rhs)
            table.insert(cmds, ir.Cmd.If(exp.loc,
                condBool,
                ir.Cmd.Seq({}),
                ir.Cmd.Seq(rhs_cmds)))

        else
            local irop = type_specific_binop(op, exp.lhs._type, exp.rhs._type)
            local v1 = self:exp_to_value(cmds, exp.lhs)
            local v2 = self:exp_to_value(cmds, exp.rhs)
            table.insert(cmds, ir.Cmd.Binop(loc, dst, irop, v1, v2))
        end

    elseif tag == "ast.Exp.Cast" then
        local dst_typ = exp._type
        local src_typ = exp.exp._type
        if src_typ._tag == dst_typ._tag then
            -- Do-nothing cast
            self:exp_to_assignment(cmds, dst, exp.exp)
        else
            local v = self:exp_to_value(cmds, exp.exp)
            if     dst_typ._tag == "types.T.Any" then
                table.insert(cmds, ir.Cmd.ToDyn(loc, src_typ, dst, v))
            elseif src_typ._tag == "types.T.Any" then
                table.insert(cmds, ir.Cmd.FromDyn(loc, dst_typ, dst, v))
            else
                error("impossible")
            end
        end

    else
        use_exp_to_value = true
    end

    if use_exp_to_value then
        local value = self:exp_to_value(cmds, exp, true)
        table.insert(cmds, ir.Cmd.Move(loc, dst, value))
    end
end

-- Returns a boolean value corresponding to whether exp is truthy.
-- As usual, may add intermediate cmds to the @cmds list
function ToIR:value_is_truthy(cmds, exp, val)
    local typ = exp._type
    if typ._tag == "types.T.Boolean" then
        return val
    elseif typ._tag == "types.T.Any" then
        local b = ir.add_local(self.func, false, types.T.Boolean())
        table.insert(cmds, ir.Cmd.IsTruthy(exp.loc, b, val))
        return ir.Value.LocalVar(b)
    else
        error("impossible")
    end
end

return to_ir
