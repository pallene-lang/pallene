local syntax_errors = {}

local errors = {
    -- The `0` label is the default "parsing failed" error number
    [0] = {
      label = "SyntaxError",
        msg = "Syntax Error" },

    { label = "MalformedNumber",
        msg = "Malformed number" },

    { label = "UnclosedLongString",
        msg = "Unclosed long string or long comment" },

    { label = "UnclosedShortString",
        msg = "Unclosed short string" },

    { label = "InvalidEscape",
        msg = "Invalid escape character in string" },

    --not used currently
    { label = "MalformedEscape_ddd",
        msg = "\\ddd escape sequences must have at most three digits."  },

    { label = "MalformedEscape_u",
        msg = "\\u escape sequence is malformed." },

    { label = "MalformedEscape_x",
        msg = "\\x escape sequences must have exactly two hexadecimal digits." },
    
    { label = "NameFunc",
        msg = "Expected a function name after 'function'." },
    
    { label = "OParenPList",
        msg = "Expected '(' for the parameter list." },
    
    { label = "CParenPList",
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
