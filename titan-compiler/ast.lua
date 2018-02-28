local typedecl = require 'titan-compiler.typedecl'

return typedecl("Ast", {
    Type = {
        TypeNil         = {"loc"},
        TypeBoolean     = {"loc"},
        TypeInteger     = {"loc"},
        TypeFloat       = {"loc"},
        TypeString      = {"loc"},
        TypeValue       = {"loc"},
        TypeName        = {"loc", "name"},
        TypeArray       = {"loc", "subtype"},
        TypeFunction    = {"loc", "argtypes", "rettypes"},
    },

    TopLevel = {
        TopLevelFunc    = {"loc", "islocal", "name", "params", "rettypes", "block"},
        TopLevelVar     = {"loc", "islocal", "decl", "value"},
        TopLevelRecord  = {"loc", "name", "fields"},
        TopLevelImport  = {"loc", "localname", "modname"}
    },

    Decl = {
        Decl            = {"loc", "name", "type"},
    },

    Stat = {
        StatBlock       = {"loc", "stats"},
        StatWhile       = {"loc", "condition", "block"},
        StatRepeat      = {"loc", "block", "condition"},
        StatIf          = {"loc", "thens", "elsestat"},
        StatFor         = {"loc", "decl", "start", "finish", "inc", "block"},
        StatAssign      = {"loc", "var", "exp"},
        StatDecl        = {"loc", "decl", "exp"},
        StatCall        = {"loc", "callexp"},
        StatReturn      = {"loc", "exp"},
    },

    Then = {
        Then            = {"loc", "condition", "block"},
    },

    Var = {
        VarName         = {"loc", "name"},
        VarBracket      = {"loc", "exp1", "exp2"},
        VarDot          = {"loc", "exp", "name"}
    },

    Exp = {
        ExpNil          = {"loc"},
        ExpBool         = {"loc", "value"},
        ExpInteger      = {"loc", "value"},
        ExpFloat        = {"loc", "value"},
        ExpString       = {"loc", "value"},
        ExpInitList     = {"loc", "fields"},
        ExpCall         = {"loc", "exp", "args"},
        ExpVar          = {"loc", "var"},
        ExpUnop         = {"loc", "op", "exp"},
        ExpConcat       = {"loc", "exps"},
        ExpBinop        = {"loc", "lhs", "op", "rhs"},
        ExpCast         = {"loc", "exp", "target"}
    },

    Args = {
        ArgsFunc        = {"loc", "args"},
        ArgsMethod      = {"loc", "method", "args"},
    },

    Field = {
        Field           = {"loc", "name", "exp"},
    },
})
