local typedecl = require "titan-compiler.typedecl"

local ast = {}

local function declare_type(typename, cons)
    typedecl.declare(ast, "ast", typename, cons)
end

declare_type("Type", {
    Nil      = {"loc"},
    Boolean  = {"loc"},
    Integer  = {"loc"},
    Float    = {"loc"},
    String   = {"loc"},
    Value    = {"loc"},
    Name     = {"loc", "name"},
    Array    = {"loc", "subtype"},
    Function = {"loc", "argtypes", "rettypes"},
})

declare_type("Toplevel", {
    Func    = {"loc", "islocal", "name", "params", "rettypes", "block"},
    Var     = {"loc", "decl", "value"},
    Record  = {"loc", "name", "field_decls"},
    Import  = {"loc", "localname", "modname"},
    Builtin = {"loc", "name"},
})

declare_type("Decl", {
    Decl = {"loc", "name", "type"},
})

declare_type("Stat", {
    Block  = {"loc", "stats"},
    While  = {"loc", "condition", "block"},
    Repeat = {"loc", "block", "condition"},
    If     = {"loc", "condition", "then_", "else_"},
    For    = {"loc", "decl", "start", "limit", "step", "block"},
    Assign = {"loc", "var", "exp"},
    Decl   = {"loc", "decl", "exp"},
    Call   = {"loc", "callexp"},
    Return = {"loc", "exps"},
})

declare_type("Var", {
    Name    = {"loc", "name"},
    Bracket = {"loc", "exp1", "exp2"},
    Dot     = {"loc", "exp", "name"}
})

declare_type("Exp", {
    Nil        = {"loc"},
    Bool       = {"loc", "value"},
    Integer    = {"loc", "value"},
    Float      = {"loc", "value"},
    String     = {"loc", "value"},
    Initlist   = {"loc", "fields"},
    CallFunc   = {"loc", "exp", "args"},
    CallMethod = {"loc", "exp", "method", "args"},
    Var        = {"loc", "var"},
    Unop       = {"loc", "op", "exp"},
    Concat     = {"loc", "exps"},
    Binop      = {"loc", "lhs", "op", "rhs"},
    Cast       = {"loc", "exp", "target"}
})

declare_type("Field", {
    Field = {"loc", "name", "exp"},
})

--
-- note: the following functions are why we need `if type(conss) == "table"`
-- in parser.lua
--

-- Return the variable name declared by a given toplevel node
function ast.toplevel_name(tlnode)
    local tag = tlnode._tag
    if     tag == ast.Toplevel.Func then
        return tlnode.name
    elseif tag == ast.Toplevel.Var then
        return tlnode.decl.name
    elseif tag == ast.Toplevel.Record then
        return tlnode.name
    elseif tag == ast.Toplevel.Import then
        return tlnode.localname
    else
        error("impossible")
    end
end

return ast
