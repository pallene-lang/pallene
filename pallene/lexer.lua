-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

--
-- This module exports lpeg patterns that can lex Pallene source code.
--
-- The lexer follows the "longest match" rule and for any given input there
-- will be at most one token that matches it. For example, lexer.LE matches
-- the start of "<=bla" but lexer.LT doesn't. This should mean that you don't
-- need to worry about what token comes first in a PEG ordered choice or about
-- the lexer splitting words in the middle (such as "localx" being parsed as
-- "local" "x").
--
-- The exported tokens are in ALLCAPS, to play nice with the "re"-style grammars
-- from parser-gen: it can only refer to our tokens if we use alphabetical
-- identifiers and it expects terminals to be uppercase and non-terminals to be
-- lowercase.

local lpeg = require "lpeglabel"

lpeg.locale(lpeg)

local P, R, S = lpeg.P, lpeg.R, lpeg.S
local C, Cb, Cg, Ct, Cmt, Cc = lpeg.C, lpeg.Cb, lpeg.Cg, lpeg.Ct, lpeg.Cmt,
    lpeg.Cc
local T = lpeg.T

local lexer = {}

--
-- Numbers
--

-- This very general pattern matches both integer and floating point numbers,
-- in either decimal or hexadecimal notation, as well as a bunch of invalid
-- stuff. We use tonumber in the end to find out which is which. This pattern
-- is intentionally more general than the one that Lua uses to avoid allowing
-- weird things such as `1337require`.
local number_start = P(".")^-1 * R("09")
local expo = S("EePp") * S("+-")^-1
local possible_number = (expo + R("09", "AZ", "az") + ".")^1
local good_number = Cmt(possible_number, function(_, i, s)
    local n = tonumber(s)
    if n then
        return i, n
    else
        return false
    end
end)
lexer.NUMBER = #number_start * (good_number + T("MalformedNumber"))

--
-- Strings
--

-- Lua's definition of a linebreak (used when skipping them inside strings)
local line_break =
    P("\n\r") +
    P("\r\n") +
    P("\n") +
    P("\r")

local long_string
do
    local equals = P("=")^0
    local open  = P("[") * Cg(equals, "open")  * P("[") * line_break^-1
    local close = P("]") * Cg(equals, "close") * P("]")

    local matching_close =
        close * Cmt( Cb("open") * Cb("close"),
            function(_source, _i, openstr, closestr)
                return openstr == closestr
            end)

    local contents = (-matching_close * P(1)) ^0

    long_string = (
        open * (
            C(contents) * close +
            T("UnclosedLongString")
        )
    ) / function(contents_str)
            -- hide the group captures
            return contents_str
        end
end

local short_string
do

    local delimiter = P('"') + P("'")

    local open  = Cg(delimiter, "open")
    local close = Cg(delimiter, "close")

    local matching_close =
        close * Cmt( Cb("open")* Cb("close"),
            function(_source, _i, open_str, close_str)
                return open_str == close_str
            end)

    -- A sequence of up to 3 decimal digits
    -- representing a non-negative integer less than 256
    local decimal_escape = P("1") * R("09") * R("09") +
        P("2") * R("04") * R("09") +
        P("2") * P("5") * R("05") +
        P("0") * R("09") * R("09") +
        R("09") * R("09") * -R("09")  +
        R("09") * -R("09") +
        R("09") * T("MalformedEscape_decimal")

    local escape_sequence = P("\\") * (
        (-P(1) * T("UnclosedShortString")) +
        (P("a")  / "\a") +
        (P("b")  / "\b") +
        (P("f")  / "\f") +
        (P("n")  / "\n") +
        (P("r")  / "\r") +
        (P("t")  / "\t") +
        (P("v")  / "\v") +
        (P("\\") / "\\") +
        (P("\'") / "\'") +
        (P("\"") / "\"") +
        (line_break / "\n") +
        C(decimal_escape) / tonumber / string.char +
        (P("u") * (P("{") * C(R("09", "af", "AF")^0) * P("}") * Cc(16) +
            T("MalformedEscape_u"))) / tonumber / utf8.char +
        (P("x") * (C(R("09", "af", "AF") * R("09", "af", "AF")) * Cc(16) +
            T("MalformedEscape_x"))) / tonumber / string.char +
        (P("z") * lpeg.space^0) +
        T("InvalidEscape")
    )

    local part = (
        (S("\n\r") * T("UnclosedShortString")) +
        escape_sequence +
        (C(P(1)))
    )

    local contents = (-matching_close * part)^0

    short_string = (
        open * (
            Ct(contents) * close +
            T("UnclosedShortString")
        )
    ) / function(parts) return table.concat(parts) end
end

lexer.STRINGLIT = short_string + long_string

--
-- Spaces and Comments
--

lexer.SPACE = S(" \t\n\v\f\r")^1

local comment_start = P("--")
local short_comment = comment_start * (P(1) - P("\n"))^0 * P("\n")^-1
local long_comment  = comment_start * long_string / function() end

lexer.COMMENT = long_comment + short_comment

--
-- Keywords and names
--

local id_start = P("_") + R("AZ", "az")
local id_rest  = P("_") + R("AZ", "az", "09")
local possible_name = id_start * id_rest^0

local keywords = {
    "and", "break", "do", "else", "elseif", "end", "for", "false",
    "function", "goto", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while", "import",
    "record", "as", "typealias",

    "boolean", "integer", "float", "string", "any"
}

for _, keyword in ipairs(keywords) do
    lexer[keyword:upper()] = P(keyword) * -id_rest
end

local is_keyword = {}
for _, keyword in ipairs(keywords) do
    is_keyword[keyword] = true
end

lexer.NAME = Cmt(C(possible_name), function(_, pos, s)
    if not is_keyword[s] then
        return pos, s
    else
        return false
    end
end)

--
-- Symbolic tokens
--

local symbols = {
    -- Lua:
    ADD  = "+",  SUB   = "-",  MUL = "*", MOD = "%",
    DIV  = "/",  IDIV  = "//", POW = "^", LEN = "#",
    BAND = "&",  BXOR  = "~",  BOR = "|",
    SHL  = "<<", SHR   = ">>", CONCAT = "..",
    EQ = "==", LT = "<",  GT = ">",
    NE = "~=", LE = "<=", GE = ">=",
    ASSIGN = "=",
    LPAREN   = "(", RPAREN   = ")",
    LBRACKET = "[", RBRACKET = "]",
    LCURLY   = "{", RCURLY   = "}",
    SEMICOLON = ";", COMMA = ",",
    DOT = ".", DOTS = "...", DBLCOLON = "::",
    -- Pallene:
    COLON = ":",
    RARROW = "->",
}

-- Enforce the longest match rule among the symbolic tokens.
for token_name, symbol in pairs(symbols) do -- token_name?
    local pat = P(symbol)
    for _ , symbol_2 in pairs(symbols) do
        if #symbol < #symbol_2 and symbol == string.sub(symbol_2, 1, #symbol) then
            pat = pat - P(symbol_2)
        end
    end
    lexer[token_name] = pat
end

-- Enforce the longest match rule when a symbolic token is a prefix of a non-symbolic one.
lexer.DOT      = lexer.DOT      - (P(".") * R("09"))
lexer.LBRACKET = lexer.LBRACKET - (P("[") * P("=")^0 * P("["))
lexer.SUB      = lexer.SUB      - P("--")

return lexer
