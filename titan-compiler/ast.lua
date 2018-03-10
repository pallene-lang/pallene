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
    Func   = {"loc", "islocal", "name", "params", "rettypes", "block"},
    Var    = {"loc", "islocal", "decl", "value"},
    Record = {"loc", "name", "field_decls"},
    Import = {"loc", "localname", "modname"},
})

declare_type("Decl", {
    Decl = {"loc", "name", "type"},
})

declare_type("Stat", {
    Block  = {"loc", "stats"},
    While  = {"loc", "condition", "block"},
    Repeat = {"loc", "block", "condition"},
    If     = {"loc", "thens", "elsestat"},
    For    = {"loc", "decl", "start", "finish", "inc", "block"},
    Assign = {"loc", "var", "exp"},
    Decl   = {"loc", "decl", "exp"},
    Call   = {"loc", "callexp"},
    Return = {"loc", "exp"},
})

declare_type("Then", {
    Then = {"loc", "condition", "block"},
})

declare_type("Var", {
    Name    = {"loc", "name"},
    Bracket = {"loc", "exp1", "exp2"},
    Dot     = {"loc", "exp", "name"}
})

declare_type("Exp", {
    Nil      = {"loc"},
    Bool     = {"loc", "value"},
    Integer  = {"loc", "value"},
    Float    = {"loc", "value"},
    String   = {"loc", "value"},
    Initlist = {"loc", "fields"},
    Call     = {"loc", "exp", "args"},
    Var      = {"loc", "var"},
    Unop     = {"loc", "op", "exp"},
    Concat   = {"loc", "exps"},
    Binop    = {"loc", "lhs", "op", "rhs"},
    Cast     = {"loc", "exp", "target"}
})

declare_type("Args", {
    Func   = {"loc", "args"},
    Method = {"loc", "method", "args"},
})

declare_type("Field", {
    Field = {"loc", "name", "exp"},
})

return ast
