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

    { label = "UnimplementedEscape_ddd",
        msg = "\\ddd escape sequences have not been implemented yet."  },

    { label = "UnimplementedEscape_u",
        msg = "\\u escape sequences have not been implemented yet." },

    { label = "UnimplementedEscape_x",
        msg = "\\x escape sequences have not been implemented yet." },

    { label = "UnimplementedEscape_a",
        msg = "\\z escape sequences have not been implemented yet." },
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
