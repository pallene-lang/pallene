--
-- This module exports lpeg patterns that can lex Titan source code.
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

local lpeg = require 'lpeglabel'

local P, R, S = lpeg.P, lpeg.R, lpeg.S
local C, Cmt  = lpeg.C, lpeg.Cmt

local lexer = {}

local function lex_error(message)
    -- TODO: figure this out
    error(message)
end

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
local possible_number = #number_start * (expo + R("09", "AZ", "az") + ".")^1
lexer.NUMBER = Cmt(possible_number, function(_, i, s)
    local n = tonumber(s)
    if n then
        return i, n
    else
        lex_error("todo: nice syntax error for malformed number")
    end
end)

--
-- Strings
--

-- If source[i] points to a newline sequence, skip it.
-- We use Lua's definition of newline sequence.
local function skip_linebreak(source, i)
    if string.match(source, "^\n\r", i) then return i + 2 end
    if string.match(source, "^\r\n", i) then return i + 2 end
    if string.match(source, "^\n", i)   then return i + 1 end
    if string.match(source, "^\r", i)   then return i + 1 end
    return i
end

local longstring_open  = P("[") * C( P("=")^0 ) * P("[")
local longstring = Cmt(longstring_open, function(source, i, equals)
    i = skip_linebreak(source, i)
    local close_str = "]" .. equals .. "]"
    local j, k = string.find(source, close_str, i, true)
    if j then
        return k+1, string.sub(source, i, j-1)
    else
        lex_error("TODO: friendly syntax error for EOF")
    end
end)

local simple_escapes = {
    ["a"]  = "\a",
    ["b"]  = "\b",
    ["f"]  = "\f",
    ["n"]  = "\n",
    ["r"]  = "\r",
    ["t"]  = "\t",
    ["v"]  = "\v",
    ["\\"] = "\\",
    ["\'"] = "\'",
    ["\""] = "\"",
}

local function do_string_escape(source, i, parts)
    if i > #source then
        return nil
    end

    local c = string.sub(source,i,i);
    i = i + 1
    
    if simple_escapes[c] then
        table.insert(parts, simple_escapes[c])
    elseif c == "\n" or c == "\r" then
        table.insert(parts, "\n") -- Same behaviour as Lua
        i = skip_linebreak(source, i-1)
    elseif string.match(c, "^[0-9]$") then
        lex_error("TODO: implement \\ddd escapes")
    elseif c == "u" then
        lex_error("TODO: implement \\u escapes")
    elseif c == "x" then
        lex_error("TODO: implement \\x escapes")
    elseif c == "z" then
        lex_error("TODO: implement \\z")
    else
        lex_error("TODO: friendly syntax error for unknown escape")
    end

    return i
end

local shortstring = Cmt( C(P('"') + P("'")), function(source, i, delimiter)
    local parts = {}

    while i <= #source do
        
        local c = string.sub(source,i,i);
        i = i + 1

        if c == delimiter then
            return i, table.concat(parts)
        elseif c == "\n" or c == "\r" then
            lex_error("TODO: friendly syntax error for unfinished string (\\n)")
        elseif c == "\\" then
            i = do_string_escape(source, i, parts)
            if not i then break end -- EOF error
        else
            table.insert(parts, c)
        end
    end

    lex_error("TODO: friendly syntax error for unfinished string (EOF)")
end)

lexer.STRING = shortstring + longstring

--
-- Spaces and Comments
--

lexer.SPACE = S(" \t\n\v\f\r")^1

local comment_start = P("--")
local short_comment = comment_start * (P(1) - P("\n"))^0 * P("\n")^-1
local long_comment  = comment_start * longstring / function() end

lexer.COMMENT = long_comment + short_comment

--
-- Keywords and names
--

local idstart = P("_") + R("AZ", "az")
local idrest  = P("_") + R("AZ", "az", "09")
local possiblename = idstart * idrest^0

local keywords = {
    "and", "break", "do", "else", "elseif", "end", "for", "false",
    "function", "goto", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while",
}

for _, keyword in ipairs(keywords) do
    lexer[keyword:upper()] = P(keyword) * -idrest
end

local is_keyword = {}
for _, keyword in ipairs(keywords) do
    is_keyword[keyword] = true
end

lexer.NAME = Cmt(C(possiblename), function(_, pos, s)
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
    -- Titan:
    COLON = ":",
}

for tokname, symbol in pairs(symbols) do
    local pat = P(symbol)
    for _ , symbol2 in pairs(symbols) do
        if #symbol < #symbol2 and symbol == string.sub(symbol2, 1, #symbol) then
            pat = pat - P(symbol2)
        end
    end
    lexer[tokname] = pat
end

-- Additional conflicts
lexer.DOT      = lexer.DOT      - (P(".") * R("09"))
lexer.LBRACKET = lexer.LBRACKET - longstring_open
lexer.SUB      = lexer.SUB      - comment_start

return lexer
