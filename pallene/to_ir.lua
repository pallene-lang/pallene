local ast = require "pallene.ast"
local ir = require "pallene.ir"
local types = require "pallene.types"

local to_ir = {}

local ToIR -- forward declaration

function to_ir.convert(module)
    for _, func in ipairs(module.functions) do
        local cmds = {}
        ToIR.new(module, func):convert_stat(cmds, func.body)
        func.body = cmds
    end
    return module, {}
end

--
--
--

ToIR = {}
ToIR.__index = ToIR

function ToIR.new(module, func)
    local self = setmetatable({}, ToIR)
    self.module = module
    self.func = func
    return self
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
        local not_cond = ast.Exp.Unop(
            stat.condition.loc, "not", stat.condition)
        not_cond._type = types.T.Boolean()

        local body = {}
        local condition = self:convert_exp(body, not_cond)
        table.insert(body, ir.Cmd.BreakIf(condition))
        self:convert_stat(body, stat.block)
        table.insert(cmds, ir.Cmd.Loop(body))

    elseif tag == "ast.Stat.Repeat" then
        local body = {}
        self:convert_stat(body, stat.block)
        local condition = self:convert_exp(body, stat.condition)
        table.insert(body, ir.Cmd.BreakIf(condition))
        table.insert(cmds, ir.Cmd.Loop(body))

    elseif tag == "ast.Stat.If" then
        local condition = self:convert_exp(cmds, stat.condition)
        local then_ = {}; self:convert_stat(then_, stat.then_)
        local else_ = {}; self:convert_stat(else_, stat.else_)
        table.insert(cmds, ir.Cmd.If(condition, then_, else_))

    elseif tag == "ast.Stat.For" then
        local start = self:convert_exp(cmds, stat.start)
        local limit = self:convert_exp(cmds, stat.limit)
        local step  = self:convert_exp(cmds, stat.step)

        local cname = stat.decl._name
        assert(cname._tag == "checker.Name.Local")
        local v = cname.id

        local body = {}
        self:convert_stat(body, stat.block)

        table.insert(cmds, ir.Cmd.For(v, start, limit, step, body))

    elseif tag == "ast.Stat.Assign" then
        local var = stat.var
        local exp = stat.exp
        if     var._tag == "ast.Var.Name" then
            local cname = var._name
            assert(cname._tag == "checker.Name.Local")
            self:convert_exp(cmds, exp, cname.id)

        elseif var._tag == "ast.Var.Bracket" then
            local arr = self:convert_exp(cmds, var.t)
            local i   = self:convert_exp(cmds, var.k)
            local v   = self:convert_exp(cmds, exp)
            table.insert(cmds, ir.Cmd.SetArr(stat.loc, arr, i, v))

        elseif var._tag == "ast.Var.Dot" then
            local field = var.name
            local rec = self:convert_exp(cmds, var.exp)
            local v   = self:convert_exp(cmds, exp)
            table.insert(cmds, ir.Cmd.SetField(stat.loc, rec, field, v))

        else
            error("impossible")
        end

    elseif tag == "ast.Stat.Decl" then
        local cname = stat.decl._name
        assert(cname._tag == "checker.Name.Local")
        local v = cname.id
        self:convert_exp(cmds, stat.exp, v)

    elseif tag == "ast.Stat.Call" then
        self:convert_exp(cmds, stat.call_exp)

    elseif tag == "ast.Stat.Return" then
        local rets = {}
        for i, exp in ipairs(stat.exps) do
            rets[i] = self:convert_exp(cmds, exp)
        end
        table.insert(cmds, ir.Cmd.Return(rets))

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

-- Converts a typecheced ast.Exp into a list of ir.Cmd
-- The converted ir.Cmd nodes are appended to the @cmds list
--
-- The optional parameter @dst is the variable name the expression's result
-- should be written to. If this parameter is missing, convert_exp will write to
-- a fresh-ly created variable instead.
--
-- Returns @dst (or the freshly-created variable)
function ToIR:convert_exp(cmds, exp, dst_opt)
    local loc = exp.loc
    local dst = dst_opt or ir.add_local(self.func, exp._type)

    local function reset_dst(new_dst)
        assert(not dst_opt)
        assert(dst == #self.func.vars)
        self.func.vars[dst] = nil
        dst = new_dst
    end

    local tag = exp._tag
    if     tag == "ast.Exp.Nil" then
        table.insert(cmds, ir.Cmd.Nil(loc, dst))

    elseif tag == "ast.Exp.Bool" then
        table.insert(cmds, ir.Cmd.Bool(loc, dst, exp.value))

    elseif tag == "ast.Exp.Integer" then
        table.insert(cmds, ir.Cmd.Integer(loc, dst, exp.value))

    elseif tag == "ast.Exp.Float" then
        table.insert(cmds, ir.Cmd.Float(loc, dst, exp.value))

    elseif tag == "ast.Exp.String" then
        table.insert(cmds, ir.Cmd.String(loc, dst, exp.value))

    elseif tag == "ast.Exp.Initlist" then
        error("not implemented")

    elseif tag == "ast.Exp.Lambda" then
        error("not implemented")

    elseif tag == "ast.Exp.CallFunc" then

        if exp._type._tag == "types.T.Void" then
            reset_dst(false)
        end

        local function get_xs()
            local xs = {}
            for i, arg_exp in ipairs(exp.args) do
                xs[i] = self:convert_exp(cmds, arg_exp)
            end
            return xs
        end

        local cname = (
            exp.exp._tag == "ast.Exp.Var" and
            exp.exp.var._tag == "ast.Var.Name" and
            exp.exp.var._name )

        if     cname and cname._tag == "checker.Name.Function" then
            local xs = get_xs()
            table.insert(cmds, ir.Cmd.CallStatic(loc, dst, cname.id, xs))

        elseif cname and cname._tag == "checker.Name.Builtin" then
            local xs = get_xs()
            table.insert(cmds, ir.Cmd.CallBuiltin(loc, dst, cname.name, xs))

        else
            local f = self:convert_exp(cmds, exp.exp)
            local xs = get_xs()
            table.insert(cmds, ir.Cmd.CallDyn(loc, dst, f, xs))
        end

    elseif tag == "ast.Exp.CallMethod" then
        error("not implemented")

    elseif tag == "ast.Exp.Var" then
        local var = exp.var
        if     var._tag == "ast.Var.Name" then
            local cname = var._name
            if     cname._tag == "checker.Name.Local" then
                local v = cname.id
                if dst_opt then
                    table.insert(cmds, ir.Cmd.Move(loc, dst, v))
                else
                    -- Move propagation optimization
                    reset_dst(v)
                end

            elseif cname._tag == "checker.Name.Function" then
                error("not implemented")

            elseif cname._tag == "checker.Name.Builtin" then
                error("not implemented")

            else
                error("impossible")
            end

        elseif var._tag == "ast.Var.Bracket" then
            local arr = self:convert_exp(cmds, var.t)
            local i   = self:convert_exp(cmds, var.k)
            table.insert(cmds, ir.Cmd.GetArr(loc, dst, arr, i))

        elseif var._tag == "ast.Var.Dot" then
            local field = var.name
            local rec = self:convert_exp(cmds, var.exp)
            table.insert(cmds, ir.Cmd.SetField(loc, dst, rec, field))

        else
            error("impossible")
        end

    elseif tag == "ast.Exp.Unop" then
        local irop = type_specific_unop(exp.op, exp.exp._type)
        local v = self:convert_exp(cmds, exp.exp)
        table.insert(cmds, ir.Cmd.Unop(loc, dst, irop, v))

    elseif tag == "ast.Exp.Concat" then
        local xs = {}
        for i, x_exp in ipairs(exp.exps) do
            xs[i] = self:convert_exp(cmds, x_exp)
        end
        table.insert(cmds, ir.Cmd.Concat(loc, dst, xs))

    elseif tag == "ast.Exp.Binop" then
        local op = exp.op
        if     op == "and" then
            self:convert_exp(cmds, exp.lhs, dst)
            local rhs_cmds = {}
            self:convert_exp(rhs_cmds, exp.rhs, dst)
            table.insert(cmds, ir.Cmd.If(dst, rhs_cmds, {}))

        elseif op == "or" then
            self:convert_exp(cmds, exp.lhs, dst)
            local rhs_cmds = {}
            self:convert_exp(rhs_cmds, exp.rhs, dst)
            table.insert(cmds, ir.Cmd.If(dst, {}, rhs_cmds))

        else
            local irop =
                type_specific_binop(op, exp.lhs._type, exp.rhs._type)
            local v1 = self:convert_exp(cmds, exp.lhs)
            local v2 = self:convert_exp(cmds, exp.rhs)
            table.insert(cmds, ir.Cmd.Binop(loc, dst, irop, v1, v2))
        end

    elseif tag == "ast.Exp.Cast" then
        local v = self:convert_exp(cmds, exp.exp)
        table.insert(cmds, ir.Cmd.Cast(loc, dst, v))

    else
        error("impossible")
    end

    return dst
end

return to_ir
