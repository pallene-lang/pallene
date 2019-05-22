local ast = require "pallene.ast"

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

function ast_iterator:Program(prog_ast, ...)
    for i = 1, #prog_ast do
        self:Toplevel(prog_ast[i], ...)
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
        self:Type(typ.subtype, ...)

    elseif tag == ast.Type.Function then
        for i = 1, #typ.arg_types do
            self:Type(typ.arg_types[i], ...)
        end
        for i = 1, #typ.ret_types do
            self:Type(typ.ret_types[i], ...)
        end

    else
        error("impossible")
    end
end

function ast_iterator:Toplevel(tl_node, ...)
    local tag = tl_node._tag
    if     tag == ast.Toplevel.Func then
        for i = 1, #tl_node.params do
            self:Decl(tl_node.params[i], ...)
        end
        for i = 1, #tl_node.ret_types do
            self:Type(tl_node.ret_types[i], ...)
        end
        self:Stat(tl_node.block, ...)

    elseif tag == ast.Toplevel.Var then
        self:Decl(tl_node.decl, ...)
        self:Exp(tl_node.value, ...)

    elseif tag == ast.Toplevel.Record then
        for i = 1, #tl_node.field_decls do
            self:Decl(tl_node.field_decls[i], ...)
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
            self:Type(decl.type, ...)
        end
    else
        error("impossible")
    end
end

function ast_iterator:Stat(stat, ...)
    local tag = stat._tag
    if     tag == ast.Stat.Block then
        for i = 1, #stat.stats do
            self:Stat(stat.stats[i], ...)
        end

    elseif tag == ast.Stat.While then
        self:Exp(stat.condition, ...)
        self:Stat(stat.block, ...)

    elseif tag == ast.Stat.Repeat then
        self:Stat(stat.block, ...)
        self:Exp(stat.condition, ...)

    elseif tag == ast.Stat.If then
        self:Exp(stat.condition, ...)
        self:Stat(stat.then_, ...)
        self:Stat(stat.else_, ...)

    elseif tag == ast.Stat.For then
        self:Decl(stat.decl, ...)
        self:Exp(stat.start, ...)
        self:Exp(stat.limit, ...)
        if stat.step then
            self:Exp(stat.step, ...)
        end
        self:Stat(stat.block, ...)

    elseif tag == ast.Stat.Assign then
        self:Var(stat.var, ...)
        self:Exp(stat.exp, ...)

    elseif tag == ast.Stat.Decl then
        self:Decl(stat.decl, ...)
        self:Exp(stat.exp, ...)

    elseif tag == ast.Stat.Call then
        self:Exp(stat.call_exp, ...)

    elseif tag == ast.Stat.Return then
        for i = 1, #stat.exps do
            self:Exp(stat.exps[i], ...)
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
        self:Exp(var.t, ...)
        self:Exp(var.k, ...)

    elseif tag == ast.Var.Dot then
        self:Exp(var.exp, ...)

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
            self:Field(exp.fields[i], ...)
        end

    elseif tag == ast.Exp.CallFunc then
        self:Exp(exp.exp, ...)
        for i = 1, #exp.args do
            self:Exp(exp.args[i], ...)
        end

    elseif tag == ast.Exp.CallMethod then
        self:Exp(exp.exp, ...)
        for i = 1, #exp.args do
            self:Exp(exp.args[i], ...)
        end

    elseif tag == ast.Exp.Var then
        self:Var(exp.var, ...)

    elseif tag == ast.Exp.Unop then
        self:Exp(exp.exp, ...)

    elseif tag == ast.Exp.Concat then
        for i = 1, #exp.exps do
            self:Exp(exp.exps[i], ...)
        end

    elseif tag == ast.Exp.Binop then
        self:Exp(exp.lhs, ...)
        self:Exp(exp.rhs, ...)

    elseif tag == ast.Exp.Cast then
        self:Exp(exp.exp, ...)
        if exp.target then
            self:Type(exp.target, ...)
        end

    else
        error("impossible")
    end
end

function ast_iterator:Field(field, ...)
    local tag = field._tag
    if tag == ast.Field.Field then
        self:Exp(field.exp, ...)
    else
        error("impossible")
    end
end

return ast_iterator
