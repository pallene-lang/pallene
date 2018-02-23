local typedecl = require 'titan-compiler.typedecl'

return typedecl({"_pos"}, "Ast", {
    Type = {
        TypeNil         = {},
        TypeBoolean     = {},
        TypeInteger     = {},
        TypeFloat       = {},
        TypeString      = {},
        TypeValue       = {},
        TypeName        = {"name"},
        TypeArray       = {"subtype"},
        TypeFunction    = {"argtypes", "rettypes"},
    },

    TopLevel = {
        TopLevelFunc    = {"islocal", "name", "params", "rettypes", "block"},
        TopLevelVar     = {"islocal", "decl", "value"},
        TopLevelRecord  = {"name", "fields"},
        TopLevelImport  = {"localname", "modname"}
    },

    Decl = {
        Decl            = {"name", "type"},
    },

    Stat = {
        StatBlock       = {"stats"},
        StatWhile       = {"condition", "block"},
        StatRepeat      = {"block", "condition"},
        StatIf          = {"thens", "elsestat"},
        StatFor         = {"decl", "start", "finish", "inc", "block"},
        StatAssign      = {"var", "exp"},
        StatDecl        = {"decl", "exp"},
        StatCall        = {"callexp"},
        StatReturn      = {"exp"},
    },

    Then = {
        Then            = {"condition", "block"},
    },

    Var = {
        VarName         = {"name"},
        VarBracket      = {"exp1", "exp2"},
        VarDot          = {"exp", "name"}
    },

    Exp = {
        ExpNil          = {},
        ExpBool         = {"value"},
        ExpInteger      = {"value"},
        ExpFloat        = {"value"},
        ExpString       = {"value"},
        ExpInitList     = {"fields"},
        ExpCall         = {"exp", "args"},
        ExpVar          = {"var"},
        ExpUnop         = {"op", "exp"},
        ExpConcat       = {"exps"},
        ExpBinop        = {"lhs", "op", "rhs"},
        ExpCast         = {"exp", "target"}
    },

    Args = {
        ArgsFunc        = {"args"},
        ArgsMethod      = {"method", "args"},
    },

    Field = {
        Field           = {"name", "exp"},
    },
})
