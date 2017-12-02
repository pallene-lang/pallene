local syntax_errors = {}

local errors = {
    -- The `0` label is the default "parsing failed" error number
    [0] = {
      label = "SyntaxError",
        msg = "Syntax Error" },

    { label = "MalformedNumber",
        msg = "Malformed number." },

    { label = "UnclosedLongString",
        msg = "Unclosed long string or long comment." },

    { label = "UnclosedShortString",
        msg = "Unclosed short string." },

    { label = "InvalidEscape",
        msg = "Invalid escape character in string." },

    --not used currently
    { label = "MalformedEscape_ddd",
        msg = "\\ddd escape sequences must have at most three digits."  },

    { label = "MalformedEscape_u",
        msg = "\\u escape sequence is malformed." },

    { label = "MalformedEscape_x",
        msg = "\\x escape sequences must have exactly two hexadecimal digits." },

    { label = "NameFunc",
        msg = "Expected a function name after 'function'." },

    { label = "LParPList",
        msg = "Expected '(' for the parameter list." },

    { label = "RParPList",
        msg = "Expected ')' to close the parameter list." },

    { label = "ColonFunc",
        msg = "Expected ':' after the parameter list." },

    { label = "TypeFunc",
        msg = "Expected a type in function declaration." },

    { label = "EndFunc",
        msg = "Expected 'end' to close the function body." },

    { label = "AssignVar",
        msg = "Expected '=' after variable declaration." },

    { label = "ExpVarDec",
        msg = "Expected an expression to initialize variable." },

    { label = "NameRecord",
        msg = "Expected a record name after 'record'." },

    { label = "EndRecord",
        msg = "Expected 'end' to close the record." },

    { label = "FieldRecord",
        msg = "Expected a field in record declaration." },

    { label = "NameImport",
        msg = "Expected a name after 'local'." },

   --this label is not thrown in rule 'import' because rule 'toplevelvar'
   --matches an invalid input like "local bola import"
   { label = "AssignImport",
        msg = "Expected '='." },

   --this label is not thrown in rule 'import' because rule 'toplevelvar'
   --matches an input like "local bola = X", given that X is a valid expression,
   --or throws a label when X is not a valid expression
   { label = "ImportImport",
        msg = "Expected 'import' keyword." },

   { label = "StringLParImport",
        msg = "Expected the name of a module after '('." },

   { label = "RParImport",
        msg = "Expected ')' to close import declaration." },

   { label = "StringImport",
        msg = "Expected the name of a module after 'import'." },

   { label = "DeclParList",
        msg = "Expected a variable name after ','." },

   { label = "TypeDecl",
        msg = "Expected a type name after ':'." },

   { label = "TypeType",
        msg = "Expected a type name after '{'." },

   { label = "RCurlyType",
        msg = "Expected '}' to close type specification." },

    { label = "TypelistType",
        msg = "Expected type after ','" },

    { label = "RParenTypelist",
        msg = "Expected ')' to close type list" },

    { label = "TypeReturnTypes",
        msg = "Expected return types after `->` to finish the function type" },

   { label = "ColonRecordField",
        msg = "Expected ':' after the name of a record field." },

   { label = "TypeRecordField",
        msg = "Expected a type name after ':'." },

   { label = "EndBlock",
        msg = "Expected 'end' to close block." },

   { label = "ExpWhile",
        msg = "Expected an expression after 'while'." },

   { label = "DoWhile",
        msg = "Expected 'do' in while statement." },

   { label = "EndWhile",
        msg = "Expected 'end' to close the while statement." },

   { label = "UntilRepeat",
        msg = "Expected 'until' in repeat statement." },

   { label = "ExpRepeat",
        msg = "Expected an expression after 'until'." },

   { label = "ExpIf",
        msg = "Expected an expression after 'if'." },

   { label = "ThenIf",
        msg = "Expected 'then' in if statement." },

   { label = "EndIf",
        msg = "Expected 'end' to close the if statement." },

   { label = "DeclFor",
        msg = "Expected variable declaration in for statement." },

   { label = "AssignFor",
        msg = "Expected '=' after variable declaration in for statement." },

   { label = "Exp1For",
        msg = "Expected an expression after '='." },

   { label = "CommaFor",
        msg = "Expected ',' in for statement." },

   { label = "Exp2For",
        msg = "Expected an expression after ','." },

   { label = "Exp3For",
        msg = "Expected an expression after ','." },

   { label = "DoFor",
        msg = "Expected 'do' in for statement." },

   { label = "EndFor",
        msg = "Expected 'end' to close the for statement." },

   { label = "DeclLocal",
        msg = "Expected variable declaration after 'local'." },

   { label = "AssignLocal",
        msg = "Expected '=' after variable declaration." },

   { label = "ExpLocal",
        msg = "Expected an expression after '='." },

   { label = "AssignAssign",
        msg = "Expected '=' after variable." },

   { label = "ExpAssign",
        msg = "Expected an expression after '='." },

   { label = "ExpElseIf",
        msg = "Expected an expression after 'elseif'." },

   { label = "ThenElseIf",
        msg = "Expected 'then' in elseif statement." },

   { label = "OpExp",
        msg = "Expected an expression after operator." },

   -- not used currently because the parser rule is commented
   { label = "NameColonExpSuf",
        msg = "Expected a method name after ':'." },

   -- not used currently because the parser rule is commented
   { label = "FuncArgsExpSuf",
        msg = "Expected a list of arguments." },

   { label = "ExpExpSuf",
        msg = "Expected an expression after '['." },

   { label = "RBracketExpSuf",
        msg = "Expected ']' to match '['." },

   { label = "NameDotExpSuf",
        msg = "Expected a function name after '.'." },

   { label = "ExpSimpleExp",
        msg = "Expected an expression after '('." },

   { label = "RParSimpleExp",
        msg = "Expected ')'to match '('." },

   { label = "RParFuncArgs",
        msg = "Expected ')' to match '('." },

   { label = "ExpExpList",
        msg = "Expected an expression after ','." },

   { label = "RCurlyTableCons",
        msg = "Expected '{' to match '}'." },

   { label = "ExpFieldList",
        msg = "Expected an expression after ',' or ';'." },

}

syntax_errors.label_to_msg = {}
syntax_errors.label_to_int = {}
syntax_errors.int_to_label = {}
syntax_errors.int_to_msg   = {}

do
    for i, t in pairs(errors) do
        local label = assert(t.label)
        local msg   = assert(t.msg)
        syntax_errors.label_to_msg[label] = msg
        syntax_errors.label_to_int[label] = i
        syntax_errors.int_to_label[i] = label
        syntax_errors.int_to_msg[i] = msg
    end
end

return syntax_errors
