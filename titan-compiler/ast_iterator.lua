local ast = require "titan-compiler.ast"

local ast_iterator = {}

--  Creates a copy of the default do-nothing iterator. The caller is expected to
--  customize it by overriding some of the methods.
function ast_iterator.new()
    local iterator = {}
    for name, func in pairs(ast_iterator.default) do
        iterator[name] = func
    end
    return iterator
end

-- Default AST iterator. Does nothing, but specific methods can be overriden
-- since all the recursive calls are late bound (via `self`).
ast_iterator.default = {}

function ast_iterator.default:Program(prog, ...)
    for i = 1, #prog do
        self:Toplevel(prog[i], ...)
    end
end

function ast_iterator.default:Type(typ, ...)
    local tag = typ._tag
    if     tag == ast.Type.Nil then  -- nothing to do
    elseif tag == ast.Type.Boolean then -- nothing to do
    elseif tag == ast.Type.Integer then -- nothing to do
    elseif tag == ast.Type.Float then -- nothing to do
    elseif tag == ast.Type.String then -- nothing to do
    elseif tag == ast.Type.Value then -- nothing to do
    elseif tag == ast.Type.Array then
        self:Type(typ.subtype, ...)

    elseif tag == ast.Type.Function then
        for i = 1, #typ.argtypes do
            self:Type(typ.argtypes[i], ...)
        end
        for i = 1, #typ.rettypes do
            self:Type(typ.rettypes[i], ...)
        end

    else
        error("impossible")
    end
end

function ast_iterator.default:Toplevel(tlnode, ...)
    local tag = tlnode._tag
    if     tag == ast.Toplevel.Func then
        for i = 1, #tlnode.params do
            self:Decl(tlnode.params[i], ...)
        end
        for i = 1, #tlnode.rettypes do
            self:Type(tlnode.rettypes[i], ...)
        end
        self:Stat(tlnode.block, ...)

    elseif tag == ast.Toplevel.Var then
        self:Decl(tlnode.decl, ...)
        self:Exp(tlnode.value, ...)

    elseif tag == ast.Toplevel.Record then
        for i = 1, #tlnode.field_decls do
            self:Decl(tlnode.field_decls[i], ...)
        end

    elseif tag == ast.Toplevel.Import then
        -- Nothing to do

    elseif tag == ast.Toplevel.Builtin then
        -- Nothing to do

    else
        error("impossible")
    end
end

function ast_iterator.default:Decl(decl, ...)
    local tag = decl._tag
    if tag == ast.Decl.Decl then
        if decl.type then
            self:Type(decl.type, ...)
        end
    else
        error("impossible")
    end
end

function ast_iterator.default:Stat(stat, ...)
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
        for i = 1, #stat.thens do
            self:Then(stat.thens[i], ...)
        end
        if stat.elsestat then
            self:Stat(stat.elsestat, ...)
        end

    elseif tag == ast.Stat.For then
        self:Decl(stat.decl, ...)
        self:Exp(stat.start, ...)
        self:Exp(stat.finish, ...)
        if stat.inc then
            self:Exp(stat.inc, ...)
        end
        self:Stat(stat.block, ...)

    elseif tag == ast.Stat.Assign then
        self:Var(stat.var, ...)
        self:Exp(stat.exp, ...)

    elseif tag == ast.Stat.Decl then
        self:Decl(stat.decl, ...)
        self:Exp(stat.exp, ...)

    elseif tag == ast.Stat.Call then
        self:Exp(stat.callexp, ...)

    elseif tag == ast.Stat.Return then
        for i = 1, #stat.exps do
            self:Exp(stat.exps[i], ...)
        end

    else
        error("impossible")
    end
end

function ast_iterator.default:Then(then_, ...)
    local tag = then_._tag
    if tag == ast.Then.Then then
        self:Exp(then_.condition, ...)
        self:Stat(then_.block, ...)
    else
        error("impossible")
    end
end

function ast_iterator.default:Var(var, ...)
    local tag = var._tag
    if     tag == ast.Var.Name then
        -- Nothing to do

    elseif tag == ast.Var.Bracket then
        self:Exp(var.exp1, ...)
        self:Exp(var.exp2, ...)

    elseif tag == ast.Var.Dot then
        self:Exp(var.exp, ...)

    else
        error("impossible")
    end
end

function ast_iterator.default:Exp(exp, ...)
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

function ast_iterator.default:Field(field, ...)
    local tag = field._tag
    if tag == ast.Field.Field then
        self:Exp(field.exp, ...)
    else
        error("impossible")
    end
end

return ast_iterator
