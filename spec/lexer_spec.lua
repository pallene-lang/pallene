local Lexer = require 'pallene.Lexer'

-- Find out how the lexer lexes a given string.
local function run_lexer(source)
    local tokens   = {}
    local captures = {}

    local lexer = Lexer.new('(lexer spec)', source)
    while true do
        local tok, err = lexer:next()
        if not tok then
            return { err = err }
        elseif tok.name == "EOF" then
            return { tokens = tokens, captures = captures }
        else
            table.insert(tokens, tok.name)
            if tok.value ~= nil then table.insert(captures, tok.value) end
        end
    end
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

describe("Pallene lexer", function()

    it("can lex some keywords", function()
        assert_lex("and", {"and"}, {})
        assert_lex("export", {"export"}, {})
    end)

    it("can lex keywords that contain other keywords", function()
        assert_lex("if",     {"if"},     {})
        assert_lex("else",   {"else"},   {})
        assert_lex("elseif", {"elseif"}, {})
        assert_lex("export", {"export"}, {})
    end)

    it("does not generate semantic values for keywords", function()
        assert_lex("nil",   {"nil"},   {})
        assert_lex("true",  {"true"},  {})
        assert_lex("false", {"false"}, {})
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
        assert_lex("+++", {"+", "+", "+"}, {})
        assert_lex(".",   {"."},           {})
        assert_lex("..",  {".."},          {})
        assert_lex("...", {"..."},         {})
        assert_lex("<==", {"<=", "="},     {})
        assert_lex("///", {"//", "/"},     {})
        assert_lex("~=",  {"~="},          {})
        assert_lex("~~=", {"~", "~="},     {})
        assert_lex("->-", {"->", "-"},     {})
        assert_lex("---", {},              {})
        assert_lex("-->", {},              {})
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
        assert_lex(".1",   {"NUMBER"},        {.1})
        assert_lex("..2",  {"..", "NUMBER"},  {2})
        assert_lex("...3", {"...", "NUMBER"}, {3})
        assert_lex("4.",   {"NUMBER"},        {4.})
    end)

    it("rejects invalid numeric literals", function()
        assert_error("1abcdef", "malformed number near '1abcdef'")
        assert_error("1.2.3.4", "malformed number near '1.2.3.4'")
        assert_error("1e",      "malformed number near '1e'")
        assert_error("1e2e3",   "malformed number near '1e2e3'")
        assert_error(".1.",     "malformed number near '.1.'")
        assert_error("4..",     "malformed number near '4..'")
    end)

    it("rejects numbers adjacent to a-f", function()
        assert_error("1337collectgarbage", [[malformed number near '1337c']])
    end)

    it("allows numbers adjacent to g-z", function()
        assert_lex("1337require", {"NUMBER", "NAME"}, {1337, "require"})
        assert_lex("1p5",         {"NUMBER", "NAME"}, {1, "p5"})
    end)

    it("correctly parses 0xe+1", function()
        assert_lex("0xe+1", {"NUMBER", "+", "NUMBER"}, {0xe, 1})
    end)

    it("can lex some short strings", function()
        assert_lex([[""]],     {"STRING"}, {""})
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

    it("can lex short strings containing decimal escapes", function()
        assert_lex('"A\\9B"',    {"STRING"}, {"A\tB"})
        assert_lex('"A\\10B"',   {"STRING"}, {"A\nB"})
        assert_lex('"A\\100B"',  {"STRING"}, {"AdB"})
        assert_lex('"A\\1000B"', {"STRING"}, {"Ad0B"})
    end)

    it("can lex short strings containing hex escapes", function()
        assert_lex('"A\\x09B"', {"STRING"}, {"A\tB"})
        assert_lex('"A\\x0AB"', {"STRING"}, {"A\nB"})
        assert_lex('"A\\x64B"', {"STRING"}, {"AdB"})
    end)

    it("can lex short strings containing utf-8 escapes", function()
        assert_lex('"A\\u{9}B"',  {"STRING"}, {"A\tB"})
        assert_lex('"A\\u{A}B"',  {"STRING"}, {"A\nB"})
        assert_lex('"A\\u{64}B"', {"STRING"}, {"AdB"})
    end)

    it("rejects invalid string escape sequences", function()
        assert_error([["\o"]], [[invalid escape sequence '\o']])
    end)

    it("rejects invalid decimal escapes", function()
        assert_error([["\256"]], "decimal escape sequence too large")
        assert_error([["\555"]], "decimal escape sequence too large")
    end)

    it("allows digits after decimal escape", function ()
        assert_lex('"\\12340"', {"STRING"}, {"{40"})
    end)

    it("rejects invalid hexadecimal escapes", function()
        assert_error([["\x"]],     "hexadecimal digit expected")
        assert_error([["\xa"]],    "hexadecimal digit expected")
        assert_error([["\xag"]],   "hexadecimal digit expected")
    end)

    it("rejects invalid unicode escapes", function()
        assert_error([["\u"]],           "missing '{'")
        assert_error([["\u{"]],          "hexadecimal digit expected")
        assert_error([["\u{ab1"]],       "missing '}'")
        assert_error([["\u{ag}"]],       "missing '}'")
        assert_error([["\u{80000000}"]], "UTF-8 value too large")
    end)

    it("rejects unclosed short strings", function()
        assert_error('"\'',        "unfinished string")
        assert_error('"A',         "unfinished string")

        assert_error('"A\n"',      "unfinished string")
        assert_error('"A\r"',      "unfinished string")
        assert_error('"A\\\n\nB"', "unfinished string")
        assert_error('"A\\\r\rB"', "unfinished string")

        assert_error('"\\"',       "unfinished string")
    end)

    it("rejects unclosed long strings", function()
        assert_error("[[]\n\n",   "unfinished long string (starting at line 1)")
        assert_error("[[]=]\n\n", "unfinished long string (starting at line 1)")
    end)

    it("can lex some long strings", function()
        assert_lex("[[abc\\o\\x\"\'def]]", {"STRING"}, {"abc\\o\\x\"\'def"})
        assert_lex("[[ ]===] ]]",          {"STRING"}, {" ]===] "})
    end)

    it("can lex long strings with overlaping close brackets", function()
        assert_lex("[==[ Hi ]]]]=]==]", {"STRING"}, {" Hi ]]]]="})
    end)

    it("can lex long strings touching square brackets", function()
        assert_lex("[[[a]]]", {"STRING", "]"}, {"[a"})
        assert_lex("[  [[a]]]", {"[", "STRING", "]"}, {"a"})
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
        assert_lex("if--then\nelse", {"if", "else"}, {})
    end)

    it("can lex short comments that go until the end of the file", function()
        assert_lex("--aaaa", {}, {})
    end)

    it("can lex long comments", function()
        assert_lex("if--[[a\n\n\n]]else", {"if", "else"}, {})
        assert_lex("--[[\nreturn 1\n--]]10", {"NUMBER"}, {10})
        assert_lex("---[[\nreturn 1\n--]]10", {"return", "NUMBER"}, {1})
    end)

    it("catches unexpected symbols", function()
        assert_error("abc $",  "unexpected symbol near '$'")
        assert_error("abc\27", "unexpected symbol near <\\27>")
    end)

    it("can lex some programs", function()
        assert_lex("local x: float = 10.0",
            {"local", "NAME", ":", "float", "=", "NUMBER"},
            {"x", 10.0})
    end)
end)
