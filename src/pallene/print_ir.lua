-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- IR PRETTY PRINTER
-- =================
-- Generates a human-readable representation of the IR.

local C = require "pallene.C"
local ir = require "pallene.ir"
local util = require "pallene.util"
local tagged_union = require "pallene.tagged_union"



local function comma_concat(ss)
    return table.concat(ss, ", ")
end

local function Var(id)
    return "x"..id
end

local function Upval(id)
    return "uv"..id
end

local function Fun(id)
    if id == 1 then
        return "main"
    else
        return "f"..id
    end
end

local function Global(id)
    return "g"..id
end

local function Val(val)
    local tag = val._tag
    if     tag == "ir.Value.Nil"      then return "nil"
    elseif tag == "ir.Value.Bool"     then return tostring(val.value)
    elseif tag == "ir.Value.Integer"  then return tostring(val.value)
    elseif tag == "ir.Value.Float"    then return C.float(val.value)
    elseif tag == "ir.Value.String"   then return C.string(val.value)
    elseif tag == "ir.Value.LocalVar" then return Var(val.id)
    elseif tag == "ir.Value.Upvalue"  then return Upval(val.id)
    else
        tagged_union.error(tag)
    end
end

local function Vars(vs)
    local ss = {}
    for i, val in ipairs(vs) do
        ss[i] = Var(val)
    end
    return ss
end

local function Vals(vals)
    local ss = {}
    for i, val in ipairs(vals) do
        ss[i] = Val(val)
    end
    return ss
end

local function Unop(op, src1)
    local opstr
    if     op == "BitNeg"  then opstr = "~"
    elseif op == "BoolNot" then opstr = "not "
    elseif op:match("Len") then opstr = "#"
    elseif op:match("Neg") then opstr = "-"
    else
        error("impossible")
    end
    return opstr..Val(src1)
end

local function Binop(op, src1, src2)
    local opstr
    if     op == "BitAnd"    then opstr = "&"
    elseif op == "BitOr"     then opstr = "|"
    elseif op == "BitXor"    then opstr = "~"
    elseif op == "BitLShift" then opstr = "<<"
    elseif op == "BitRShift" then opstr = ">>"
    elseif op:match("Add")   then opstr = "+"
    elseif op:match("Sub")   then opstr = "-"
    elseif op:match("Mul")   then opstr = "*"
    elseif op:match("Divi")  then opstr = "//"
    elseif op:match("Mod")   then opstr = "%"
    elseif op:match("Div")   then opstr = "/"
    elseif op:match("Pow")   then opstr = "^"
    elseif op:match("Eq")    then opstr = "=="
    elseif op:match("Neq")   then opstr = "~="
    elseif op:match("Lt")    then opstr = "<"
    elseif op:match("Gt")    then opstr = ">"
    elseif op:match("Leq")   then opstr = "<="
    elseif op:match("Geq")   then opstr = ">="
    else
        error("impossible")
    end
    return Val(src1).." "..opstr.." "..Val(src2)
end

local function Bracket(t, k)
    return util.render("$t[$k]", { t = Val(t), k = Val(k) })
end

local function Field(t, field)
    return util.render("$t.$field", {  t = Val(t), field = field })
end

local function Call(fname, args)
    return fname .. "(" .. comma_concat(args) .. ")"
end

local function Cmd(cmd)
    local tag = cmd._tag

    local lhs
    if     tag == "ir.Cmd.Nop" then
        return "nop"
    elseif tag == "ir.Cmd.Return" then
        return "return " .. comma_concat(Vals(cmd.srcs))
    elseif tag == "ir.Cmd.SetArr"      then lhs = Bracket(cmd.src_arr, cmd.src_i)
    elseif tag == "ir.Cmd.SetTable"    then lhs = Bracket(cmd.src_tab, cmd.src_k)
    elseif tag == "ir.Cmd.SetField"    then lhs = Field(cmd.src_rec, cmd.field_name)
    elseif tag == "ir.Cmd.InitUpvalues" then lhs = Val(cmd.src_f) .. ".upvalues"
    else
        lhs = comma_concat(Vars(ir.get_dsts(cmd)))
    end

    local rhs
    if     tag == "ir.Cmd.Move"       then rhs = Val(cmd.src)
    elseif tag == "ir.Cmd.GetGlobal"  then rhs = Global(cmd.global_id)
    elseif tag == "ir.Cmd.Unop"       then rhs = Unop(cmd.op, cmd.src)
    elseif tag == "ir.Cmd.Binop"      then rhs = Binop(cmd.op, cmd.src1, cmd.src2)
    elseif tag == "ir.Cmd.GetArr"     then rhs = Bracket(cmd.src_arr, cmd.src_i)
    elseif tag == "ir.Cmd.SetArr"     then rhs = Val(cmd.src_v)
    elseif tag == "ir.Cmd.GetTable"   then rhs = Bracket(cmd.src_tab, cmd.src_k)
    elseif tag == "ir.Cmd.SetTable"   then rhs = Val(cmd.src_v)
    elseif tag == "ir.Cmd.NewRecord"  then rhs = "new ".. cmd.rec_typ.name .."()"
    elseif tag == "ir.Cmd.GetField"   then rhs = Field(cmd.src_rec, cmd.field_name)
    elseif tag == "ir.Cmd.SetField"   then rhs = Val(cmd.src_v)
    elseif tag == "ir.Cmd.NewClosure" then rhs = Call("NewClosure", { Fun(cmd.f_id) })
    elseif tag == "ir.Cmd.InitUpvalues" then rhs = comma_concat(Vals(cmd.srcs))
    elseif tag == "ir.Cmd.CallStatic" then
        rhs = "CallStatic ".. Call(Val(cmd.src_f), Vals(cmd.srcs))
    elseif tag == "ir.Cmd.CallDyn" then
        rhs = "CallDyn ".. Call(Val(cmd.src_f), Vals(cmd.srcs))
    elseif tagged_union.typename(cmd._tag) == "ir.Cmd" then
        local name = tagged_union.consname(cmd._tag)
        rhs = Call(name, Vals(ir.get_srcs(cmd)))
    end

    if lhs == "" then
        return rhs
    else
        return lhs.." <- "..rhs
    end
end

local function print_block(block, index)
    local parts = {}
    local space = "    "
    for i, cmd in ipairs(block.cmds) do
        parts[i] = space .. Cmd(cmd)
    end
    if block.jmp_false then
        table.insert(parts,
                space .. "jmpf " ..
                block.jmp_false.target .. ", " ..
                Val(block.jmp_false.src_condition))
    end
    if block.next and block.next ~= index + 1 then
        table.insert(parts, space .. "jmp "  .. block.next)
    end
    local str = table.concat(parts, "\n")
    return #str > 0 and str .. "\n" or ""
end

local function print_block_list(blocks)
    local parts = {}
    for i, b in ipairs(blocks) do
        parts[i] = util.render(
                "  $num:\n$body",
                {num = tostring(i), body = print_block(b, i)})
    end
    return table.concat(parts)
end


local function print_ir(module)
    local parts = {}
    for f_id, func in ipairs(module.functions) do
        local vs = {}
        for i = 1, #func.typ.arg_types do
            vs[i] = i
        end

        table.insert(parts, util.render(
            "function $proto {\n$body}\n", {
            proto = Call(Fun(f_id), Vars(vs)),
            body  = print_block_list(func.blocks),
        }))
    end
    return table.concat(parts, "\n")
end

return print_ir
