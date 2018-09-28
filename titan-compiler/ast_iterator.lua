local ast = require "titan-compiler.ast"

-- AST iterator/modifier class. The default implementation does nothing, but
-- specific methods can be overriden since all the recursive cals are late bound
-- (with `self`).
--
-- The iterator has one method for each type of AST node. If the method returns
-- `nil` then it just iterates but if it returns a new node the original node is
-- replaced with that one (in place).
local ast_iterator = {}
ast_iterator.__index = ast_iterator

--  Creates a copy of the default do-nothing iterator. The caller is expected to
--  customize it by overriding some of the methods.
function ast_iterator.new()
    return setmetatable({}, ast_iterator)
end

function ast_iterator:Program(prog, ...)
    for i = 1, #prog do
        prog[i] = self:Toplevel(prog[i], ...) or prog[i]
    end
end

function ast_iterator:Type(typ, ...)
    local tag = typ._tag
    if     tag == ast.Type.Nil then  -- nothing to do
    elseif tag == ast.Type.Boolean then -- nothing to do
    elseif tag == ast.Type.Integer then -- nothing to do
    elseif tag == ast.Type.Float then -- nothing to do
    elseif tag == ast.Type.String then -- nothing to do
    elseif tag == ast.Type.Value then -- nothing to do
    elseif tag == ast.Type.Name then -- nothing to do
    elseif tag == ast.Type.Array then
        typ.subtype = self:Type(typ.subtype, ...) or typ.subtype

    elseif tag == ast.Type.Function then
        for i = 1, #typ.argtypes do
            typ.argtypes[i] = self:Type(typ.argtypes[i], ...) or typ.argtypes[i]
        end
        for i = 1, #typ.rettypes do
            typ.rettypes[i] = self:Type(typ.rettypes[i], ...) or typ.rettypes[i]
        end

    else
        error("impossible")
    end
end

function ast_iterator:Toplevel(tlnode, ...)
    local tag = tlnode._tag
    if     tag == ast.Toplevel.Func then
        for i = 1, #tlnode.params do
            tlnode.params[i] = self:Decl(tlnode.params[i], ...) or tlnode.params[i]
        end
        for i = 1, #tlnode.rettypes do
            tlnode.rettypes[i] = self:Type(tlnode.rettypes[i], ...) or tlnode.rettypes[i]
        end
        tlnode.block = self:Stat(tlnode.block, ...) or tlnode.block

    elseif tag == ast.Toplevel.Var then
        tlnode.decl = self:Decl(tlnode.decl, ...) or tlnode.decl
        tlnode.value = self:Exp(tlnode.value, ...) or tlnode.value

    elseif tag == ast.Toplevel.Record then
        for i = 1, #tlnode.field_decls do
            tlnode.field_decls[i] = self:Decl(tlnode.field_decls[i], ...) or tlnode.field_decls[i]
        end

    elseif tag == ast.Toplevel.Import then
        -- Nothing to do

    elseif tag == ast.Toplevel.Builtin then
        -- Nothing to do

    else
        error("impossible")
    end
end

function ast_iterator:Decl(decl, ...)
    local tag = decl._tag
    if tag == ast.Decl.Decl then
        if decl.type then
            decl.type = self:Type(decl.type, ...) or decl.type
        end
    else
        error("impossible")
    end
end

function ast_iterator:Stat(stat, ...)
    local tag = stat._tag
    if     tag == ast.Stat.Block then
        for i = 1, #stat.stats do
            stat.stats[i] = self:Stat(stat.stats[i], ...) or stat.stats[i]
        end

    elseif tag == ast.Stat.While then
        stat.condition = self:Exp(stat.condition, ...) or stat.condition
        stat.block = self:Stat(stat.block, ...) or stat.block

    elseif tag == ast.Stat.Repeat then
        stat.block = self:Stat(stat.block, ...) or stat.block
        stat.condition = self:Exp(stat.condition, ...) or stat.condition

    elseif tag == ast.Stat.If then
        stat.condition = self:Exp(stat.condition, ...) or stat.condition
        stat.then_ = self:Stat(stat.then_, ...) or stat.then_
        stat.else_ = self:Stat(stat.else_, ...) or stat.else_

    elseif tag == ast.Stat.For then
        stat.decl = self:Decl(stat.decl, ...) or stat.decl
        stat.start = self:Exp(stat.start, ...) or stat.start
        stat.finish = self:Exp(stat.finish, ...) or stat.finish
        if stat.inc then
            stat.inc = self:Exp(stat.inc, ...) or stat.inc
        end
        stat.block = self:Stat(stat.block, ...) or stat.block

    elseif tag == ast.Stat.Assign then
        stat.var = self:Var(stat.var, ...) or stat.var
        stat.exp = self:Exp(stat.exp, ...) or stat.exp

    elseif tag == ast.Stat.Decl then
        stat.decl = self:Decl(stat.decl, ...) or stat.decl
        stat.exp = self:Exp(stat.exp, ...) or stat.exp

    elseif tag == ast.Stat.Call then
        stat.callexp = self:Exp(stat.callexp, ...) or stat.callexp

    elseif tag == ast.Stat.Return then
        for i = 1, #stat.exps do
            stat.exps[i] = self:Exp(stat.exps[i], ...) or stat.exps[i]
        end

    else
        error("impossible")
    end
end

function ast_iterator:Var(var, ...)
    local tag = var._tag
    if     tag == ast.Var.Name then
        -- Nothing to do

    elseif tag == ast.Var.Bracket then
        var.exp1 = self:Exp(var.exp1, ...) or var.exp1
        var.exp2 = self:Exp(var.exp2, ...) or var.exp2

    elseif tag == ast.Var.Dot then
        var.exp = self:Exp(var.exp, ...) or var.exp

    else
        error("impossible")
    end
end

function ast_iterator:Exp(exp, ...)
    local tag = exp._tag
    if     tag == ast.Exp.Nil then -- Nothing to do
    elseif tag == ast.Exp.Bool then -- Nothing to do
    elseif tag == ast.Exp.Integer then -- Nothing to do
    elseif tag == ast.Exp.Float then -- Nothing to do
    elseif tag == ast.Exp.String then -- Nothing to do
    elseif tag == ast.Exp.Initlist then
        for i = 1, #exp.fields do
            exp.fields[i] = self:Field(exp.fields[i], ...) or exp.fields[i]
        end

    elseif tag == ast.Exp.CallFunc then
        exp.exp = self:Exp(exp.exp, ...) or exp.exp
        for i = 1, #exp.args do
            exp.args[i] = self:Exp(exp.args[i], ...) or exp.args[i]
        end

    elseif tag == ast.Exp.CallMethod then
        exp.exp = self:Exp(exp.exp, ...) or exp.exp
        for i = 1, #exp.args do
            exp.args[i] = self:Exp(exp.args[i], ...) or exp.args[i]
        end


    elseif tag == ast.Exp.Var then
        exp.var = self:Var(exp.var, ...) or exp.var

    elseif tag == ast.Exp.Unop then
        exp.exp = self:Exp(exp.exp, ...) or exp.exp

    elseif tag == ast.Exp.Concat then
        for i = 1, #exp.exps do
            exp.exps[i] = self:Exp(exp.exps[i], ...) or exp.exps[i]
        end

    elseif tag == ast.Exp.Binop then
        exp.lhs = self:Exp(exp.lhs, ...) or exp.lhs
        exp.rhs = self:Exp(exp.rhs, ...) or exp.rhs

    elseif tag == ast.Exp.Cast then
        exp.exp = self:Exp(exp.exp, ...) or exp.exp
        if exp.target then
            exp.target = self:Type(exp.target, ...) or exp.target
        end

    else
        error("impossible")
    end
end

function ast_iterator:Field(field, ...)
    local tag = field._tag
    if tag == ast.Field.Field then
        field.exp = self:Exp(field.exp, ...) or field.exp
    else
        error("impossible")
    end
end

return ast_iterator
