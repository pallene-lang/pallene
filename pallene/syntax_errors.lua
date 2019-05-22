local syntax_errors = {}

local errors = {
    -- The `fail` label is the default "parsing failed" error number
    fail = "Syntax Error",

    --
    -- Lexer errors
    -- (tested in spec/lexer_spec.lua)
    --

    MalformedNumber = "Malformed number.",

    UnclosedLongString = "Unclosed long string or long comment.",

    UnclosedShortString = "Unclosed short string.",

    InvalidEscape = "Invalid escape character in string." ,

    MalformedEscape_decimal = "Decimal escape too large",

    MalformedEscape_u = "\\u escape sequence is malformed.",

    MalformedEscape_x = "\\x escape sequences must have exactly two hexadecimal digits.",

    --
    -- Parser errors
    -- (tested in spec/parser_spec.lua)
    --

    NameFunc = "Expected a function name after 'function'.",

    LParPList = "Expected '(' for the parameter list.",

    RParPList = "Expected ')' to close the parameter list.",

    TypeFunc = "Expected a type in function declaration.",

    EndFunc = "Expected 'end' to close the function body.",

    ParamSemicolon = "Expected ':' after parameter name.",

    AssignVar = "Expected '=' after variable declaration.",

    ExpVarDec = "Expected an expression to initialize variable.",

    NameRecord = "Expected a record name after 'record'.",

    EndRecord = "Expected 'end' to close the record.",

    NameImport = "Expected a name after 'local'.",

    --this label is not thrown in rule 'import' because rule 'toplevelvar'
    --matches an invalid input like "local bola import"
    AssignImport = "Expected '='.",

    --this label is not thrown in rule 'import' because rule 'toplevelvar'
    --matches an input like "local bola = X", given that X is a valid
    --expression, or throws a label when X is not a valid expression
    ImportImport = "Expected 'import' keyword.",

    StringLParImport = "Expected the name of a module after '('.",

    RParImport = "Expected ')' to close import declaration.",

    StringImport = "Expected the name of a module after 'import'.",

    DeclParList = "Expected a variable name after ','.",

    TypeDecl = "Expected a type name after ':'.",

    TypeType = "Expected a type name after '{'.",

    RCurlyType = "Expected '}' to close type specification.",

    TypelistType = "Expected type after ','",

    RParenTypelist = "Expected ')' to close type list",

    TypeReturnTypes = "Expected return types after `->` to finish the function type",

    ColonRecordField = "Expected ':' after the name of a record field.",

    TypeRecordField = "Expected a type name after ':'.",

    EndBlock = "Expected 'end' to close block.",

    ExpWhile = "Expected an expression after 'while'.",

    DoWhile = "Expected 'do' in while statement.",

    EndWhile = "Expected 'end' to close the while statement.",

    UntilRepeat = "Expected 'until' in repeat statement.",

    ExpRepeat = "Expected an expression after 'until'.",

    ExpIf = "Expected an expression after 'if'.",

    ThenIf = "Expected 'then' in if statement.",

    EndIf = "Expected 'end' to close the if statement.",

    DeclFor = "Expected variable declaration in for statement.",

    AssignFor = "Expected '=' after variable declaration in for statement.",

    Exp1For = "Expected an expression after '='.",

    CommaFor = "Expected ',' in for statement.",

    Exp2For = "Expected an expression after ','.",

    Exp3For = "Expected an expression after ','.",

    DoFor = "Expected 'do' in for statement.",

    EndFor = "Expected 'end' to close the for statement.",

    DeclLocal = "Expected variable declaration after 'local'.",

    AssignLocal = "Expected '=' after variable declaration.",

    ExpLocal = "Expected an expression after '='.",

    AssignAssign = "Expected '=' after variable.",

    ExpAssign = "Expected an expression after '='.",

    ExpElseIf = "Expected an expression after 'elseif'.",

    ThenElseIf = "Expected 'then' in elseif statement.",

    OpExp = "Expected an expression after operator.",

    NameColonExpSuf = "Expected a method name after ':'.",

    FuncArgsExpSuf = "Expected a list of arguments.",

    ExpExpSuf = "Expected an expression after '['.",

    RBracketExpSuf = "Expected ']' to match '['.",

    NameDotExpSuf = "Expected a function name after '.'.",

    ExpSimpleExp = "Expected an expression after '('.",

    RParSimpleExp = "Expected ')'to match '('.",

    RParFuncArgs = "Expected ')' to match '('.",

    ExpExpList = "Expected an expression after ','.",

    RCurlyInitList = "Expected '{' to match '}'.",

    ExpFieldList = "Expected an expression after ',' or ';'.",

    ExpStat = "Expected a statement but found an expression that is not a function call",

    AssignNotToVar = "Expected a valid lvalue in the left side of assignment but found a regular expression",

    CastMissingType = "Expected a type for the cast expression",
}

syntax_errors.errors = errors

return syntax_errors
