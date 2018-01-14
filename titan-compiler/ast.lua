local typedecl = require 'titan-compiler.typedecl'

return typedecl({"_pos"}, true, {
    Type = {
        Name        = {"name"},
        Array       = {"subtype"},
        Function    = {"argtypes", "rettypes"},
    },

    TopLevel = {
        Func        = {"islocal", "name", "params", "rettypes", "block"},
        Var         = {"islocal", "decl", "value"},
        Record      = {"name", "fields"},
        Import      = {"localname", "modname"}
    },

    Decl = {
        Decl        = {"name", "type"},
    },

    Stat = {
        Block       = {"stats"},
        While       = {"condition", "block"},
        Repeat      = {"block", "condition"},
        If          = {"thens", "elsestat"},
        For         = {"decl", "start", "finish", "inc", "block"},
        Assign      = {"var", "exp"},
        Decl        = {"decl", "exp"},
        Call        = {"callexp"},
        Return      = {"exp"},
    },

    Then = {
        Then        = {"condition", "block"},
    },

    Var = {
        Name        = {"name"},
        Bracket     = {"exp1", "exp2"},
        Dot         = {"exp", "name"}
    },

    Exp = {
        Nil         = {},
        Bool        = {"value"},
        Integer     = {"value"},
        Float       = {"value"},
        String      = {"value"},
        InitList    = {"fields"},
        Call        = {"exp", "args"},
        Var         = {"var"},
        Unop        = {"op", "exp"},
        Concat      = {"exps"},
        Binop       = {"lhs", "op", "rhs"},
        Cast        = {"exp", "target"}
    },

    Args = {
        Func        = {"args"},
        Method      = {"method", "args"},
    },

    Field = {
        Field       = {"name", "exp"},
    },
})
