local lexer = require 'titan-compiler.lexer'
local syntax_errors = require 'titan-compiler.syntax_errors'
local lpeg = require 'lpeglabel'

local function table_extend(t1, t2)
    table.move(t2, 1, #t2, #t1+1, t1)
end

-- Find out how the lexer lexes a given string.
-- Produces an error message if the string cannot be lexed or if there
-- are multiple ways to lex it.
local function run_lexer(source)
    local all_matched_tokens = {}
    local all_captures = {}

    local i = 1
    while i <= #source do

        local found_token = nil
        local found_captures = nil
        local found_j = nil

        for tokname, tokpat in pairs(lexer) do
            local a, b, c = lpeg.match(lpeg.Ct(tokpat) * lpeg.Cp(), source, i)
            if a then
                local captures, j = a, b
                if i == j then
                    return string.format(
                        "error: token %s matched the empty string",
                        tokname)
                elseif found_token then
                    return string.format(
                        "error: multiple matching tokens: %s %s",
                         found_token, tokname)
                else
                    found_token = tokname
                    found_captures = captures
                    found_j = j
                end
            elseif b and b > 0 then
                local errnum, suffix = b, c
                local errcode = syntax_errors.int_to_label[errnum]
                return { err = errcode }
            end
        end

        if not found_token then
            return "error: lexer got stuck"
        end

        table.insert(all_matched_tokens, found_token)
        table_extend(all_captures, found_captures)
        i = found_j
    end

    return { tokens = all_matched_tokens, captures = all_captures }
end

local function assert_lex(source, expected_tokens, expected_captures)
    local lexed    = run_lexer(source)
    local expected = { tokens = expected_tokens, captures = expected_captures }
    assert.are.same(expected, lexed)
end

local function assert_error(source, expected_error )
    local lexed    = run_lexer(source)
    local expected = { err = expected_error }
    assert.are.same(expected, lexed)
end

describe("Titan lexer", function()

    it("can lex some keywords", function()
        assert_lex("and", {"AND"}, {})
    end)

    it("can lex keywords that contain other keywords", function()
        assert_lex("if",     {"IF"},     {})
        assert_lex("else",   {"ELSE"},   {})
        assert_lex("elseif", {"ELSEIF"}, {})
    end)

    it("does not generate semantic values for keywords", function()
        assert_lex("nil",   {"NIL"},   {})
        assert_lex("true",  {"TRUE"},  {})
        assert_lex("false", {"FALSE"}, {})
    end)

    it("can lex some identifiers", function()
        assert_lex("hello",    {"NAME"}, {"hello"})
        assert_lex("_",        {"NAME"}, {"_"})
        assert_lex("_test_17", {"NAME"}, {"_test_17"})
    end)

    it("can lex identifiers containing keywords", function()
        assert_lex("return17", {"NAME"}, {"return17"})
        assert_lex("andy",     {"NAME"}, {"andy"})
        assert_lex("_end",     {"NAME"}, {"_end"})
    end)

    it("can lex sequences of symbols without spaces", function()
        assert_lex("+++", {"ADD", "ADD", "ADD"}, {})
        assert_lex(".",   {"DOT"},               {})
        assert_lex("..",  {"CONCAT"},            {})
        assert_lex("...", {"DOTS"},              {})
        assert_lex("<==", {"LE", "ASSIGN"},      {})
        assert_lex("---", {"COMMENT"},           {})
        assert_lex("///", {"IDIV", "DIV"},       {})
        assert_lex("~=",  {"NE"},                {})
        assert_lex("~~=", {"BXOR", "NE"},        {})
        assert_lex("->-", {"RARROW", "SUB"},     {})
        assert_lex("-->", {"COMMENT"},           {})
    end)

    it("can lex some integers", function()
        assert_lex("0",            {"NUMBER"}, {0})
        assert_lex("17",           {"NUMBER"}, {17})
        assert_lex("0x1abcdef",    {"NUMBER"}, {0x1abcdef})
        assert_lex("0x1ABCDEF",    {"NUMBER"}, {0x1ABCDEF})
    end)

    it("can lex some floats", function()
        assert_lex("0.0",          {"NUMBER"}, {0.0})
        assert_lex("0.",           {"NUMBER"}, {0.})
        assert_lex(".0",           {"NUMBER"}, {.0})
        assert_lex("1.0e+1",       {"NUMBER"}, {1.0e+1})
        assert_lex("1.0e-1",       {"NUMBER"}, {1.0e-1})
        assert_lex("1e10",         {"NUMBER"}, {1e10})
        assert_lex("1E10",         {"NUMBER"}, {1E10})
        assert_lex("0x1ap2",       {"NUMBER"}, {0x1ap2})
    end)

    it("does the right thing with dots touching numbers", function()
        assert_lex(".1",   {"NUMBER"},           {.1})
        assert_lex("..2",  {"CONCAT", "NUMBER"}, {2})
        assert_lex("...3", {"DOTS", "NUMBER"},   {3})
        assert_lex("4.",   {"NUMBER"},           {4})
    end)

    it("errors out on invalid numbers (instead of backtracking)", function()
        assert_error("1abcdef", "MalformedNumber")
        assert_error("1.2.3.4", "MalformedNumber")
        assert_error("1e",      "MalformedNumber")
        assert_error("1e2e3",   "MalformedNumber")
        assert_error("1p5",     "MalformedNumber")
        assert_error(".1.",     "MalformedNumber")
        assert_error("4..",     "MalformedNumber")

        -- This is actually accepted by Lua (!)
        assert_error("local x = 1337require",        "MalformedNumber")

        -- This is rejected by Lua ('c' is an hexdigit)
        assert_error("local x = 1337collectgarbage", "MalformedNumber")
    end)

    it("can lex some short strings", function()
        assert_lex([[""]], {"STRING"}, {""})
        assert_lex([["asdf"]], {"STRING"}, {"asdf"})
    end)

    it("doesn't eat the spaces inside a string", function()
        assert_lex([[" asdf  "]], {"STRING"}, {" asdf  "})
    end)

    it("can lex short strings containg quotes", function()
        assert_lex([["O'Neil"]],    {"STRING"}, {"O\'Neil"})
        assert_lex([['aa"bb"cc']],  {"STRING"}, {"aa\"bb\"cc"})
    end)

    it("can lex short strings containing escape sequences", function()
        assert_lex([["\a\b\f\n\r\t\v\\\'\""]], {"STRING"}, {"\a\b\f\n\r\t\v\\\'\""})
    end)

    it("can lex short strings containing escaped newlines", function()
        assert_lex('"A\\\nB"',   {"STRING"}, {"A\nB"})
        assert_lex('"A\\\rB"',   {"STRING"}, {"A\nB"})
        assert_lex('"A\\\n\rB"', {"STRING"}, {"A\nB"})
        assert_lex('"A\\\r\nB"', {"STRING"}, {"A\nB"})
    end)

    it("can lex short strings containing digit escapes", function()
        assert_lex('"A\\9B"',   {"STRING"}, {"A\tB"})
        assert_lex('"A\\10B"',   {"STRING"}, {"A\nB"})
        assert_lex('"A\\100B"', {"STRING"}, {"AdB"})
    end)

    it("can lex short strings containing hex escapes", function()
        assert_lex('"A\\x09B"',   {"STRING"}, {"A\tB"})
        assert_lex('"A\\x0AB"',   {"STRING"}, {"A\nB"})
        assert_lex('"A\\x64B"', {"STRING"}, {"AdB"})
    end)

    it("can lex short strings containing utf-8 escapes", function()
        assert_lex('"A\\u{9}B"',   {"STRING"}, {"A\tB"})
        assert_lex('"A\\u{A}B"',   {"STRING"}, {"A\nB"})
        assert_lex('"A\\u{64}B"', {"STRING"}, {"AdB"})
    end)

    it("errors out on invalid excape sequences (instead of backtracking)", function()
        assert_error([["\o"]], "InvalidEscape")
        assert_error([["\x"]], "MalformedEscape_x")
        assert_error([["\xa"]], "MalformedEscape_x")
        assert_error([["\u"]], "MalformedEscape_u")
        assert_error([["\u{"]], "MalformedEscape_u")
        assert_error([["\u{ab1"]], "MalformedEscape_u")
    end)

    it("errors out on unclosed strings (instead of backtracking)", function()
        assert_error('"\'',       "UnclosedShortString")
        assert_error('"A',        "UnclosedShortString")

        assert_error('"A\n',      "UnclosedShortString")
        assert_error('"A\r',      "UnclosedShortString")
        assert_error('"A\\\n\nB', "UnclosedShortString")
        assert_error('"A\\\r\rB', "UnclosedShortString")

        assert_error('"\\"',      "UnclosedShortString")

        assert_error("[[]",   "UnclosedLongString")
        assert_error("[[]=]", "UnclosedLongString")
    end)

    it("can lex some long strings", function()
        assert_lex("[[abc\\o\\x\"\'def]]", {"STRING"}, {"abc\\o\\x\"\'def"})
        assert_lex("[[ ]===] ]]",          {"STRING"}, {" ]===] "})
    end)

    it("can lex long strings with overlaping close brackets", function()
        assert_lex("[==[ Hi ]]]]=]==]", {"STRING"}, {" Hi ]]]]="})
    end)

    it("can lex long strings touching square brackets", function()
        assert_lex("[[[a]]]", {"STRING", "RBRACKET"}, {"[a"})
        assert_lex("[  [[a]]]", {"LBRACKET", "SPACE", "STRING", "RBRACKET"}, {"a"})
    end)

    it("ignores newlines at the start of a long string", function()
        assert_lex("[[\nhello]]",   {"STRING"}, {"hello"})
        assert_lex("[[\rhello]]",   {"STRING"}, {"hello"})
        assert_lex("[[\n\rhello]]", {"STRING"}, {"hello"})
        assert_lex("[[\r\nhello]]", {"STRING"}, {"hello"})
        assert_lex("[[\n\nhello]]", {"STRING"}, {"\nhello"})
        assert_lex("[[\r\rhello]]", {"STRING"}, {"\rhello"})
    end)

    it("can lex some short comments", function()
        assert_lex("if--then\nelse", {"IF", "COMMENT", "ELSE"}, {})
    end)

    it("can lex short comments that go until the end of the file", function()
        assert_lex("--aaaa", {"COMMENT"}, {})
    end)

    it("can lex long some comments", function()
        assert_lex("if--[[a\n\n\n]]else", {"IF", "COMMENT", "ELSE"}, {})

        assert_lex(
            "--[[\n" ..
            "return 1\n" ..
            "--]]",
            {"COMMENT"}, {}
        )

        assert_lex(
            "---[[\n" ..
            "return 1\n" ..
            "--]]",
            {"COMMENT", "RETURN", "SPACE", "NUMBER", "SPACE", "COMMENT"}, {1}
        )

    end)

    it("can lex some programs", function()
        assert_lex("local x: float = 10.0",
            {"LOCAL", "SPACE", "NAME", "COLON", "SPACE", "NAME",
             "SPACE", "ASSIGN", "SPACE", "NUMBER"},
            {"x", "float", 10.0})
    end)
end)
