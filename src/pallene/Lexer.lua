-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- PALLENE LEXER
-- =============
-- This module implements the Pallene lexer, which is loosely based on the Lua lexer from llex.c.
-- In particular, we also reuse most of the error messages. One small difference is that we don't
-- write the "near xxx" when a lexer error happens inside a string, because that info is redundant
-- with the column numbers that we provide and Lua doesn't. Another difference is that we raise an
-- error if we encounter an unexpected symbol, instead of punting that to the parser.

local lpeg = require "lpeg"
local re = require "re"
local Location = require "pallene.Location"
local util = require "pallene.util"

local P  = lpeg.P
local RE = re.compile

local one_char = P(1)

local space = RE"[ \t\n\v\f\r]+"
local newline = P"\n\r" + P"\r\n" + P"\n" + P"\r" -- See inclinenumber in llex.c
local find_newline = (1 - newline)^0 * newline

local comment_line = RE"[^\n\r]*" * newline^-1

local longstring_open    = P("[") * P("=")^0 * P("[")
local longstring_content = (1 - P("]"))^1 + P("]")

local string_delimiter  = RE"[\"\']"
local string_content    = RE"[^\"\'\n\r\\]+"
local string_hex_number = RE"[0-9A-Fa-f][0-9A-Fa-f]?"
local string_dec_number = RE"[0-9][0-9]?[0-9]?"
local string_u_number   = RE"[0-9A-Fa-f]+"

local string_escapes = {
    ["a"] = "\a",  ["b"] = "\b", ["f"] = "\f",  ["n"] = "\n",  ["r"] = "\r",
    ["t"] = "\t",  ["v"] = "\v", ["\\"] = "\\", ["\'"] = "\'", ["\""] = "\"",
}

local possible_number = RE[[
      [0][Xx] ([Pp][+-]? / [.0-9A-Fa-f])* /
    [.]?[0-9] ([Ee][+-]? / [.0-9A-Fa-f])*]] -- See read_numeral in llex.c

local identifier = RE"[_A-Za-z][_A-Za-z0-9]*"
local is_keyword = {}
do
    local strs = [[
        and break do else elseif end for false function goto if in local nil not or repeat return
        then true until while   as record typealias
    ]]
    for s in string.gmatch(strs, "%S+") do
        is_keyword[s] = true
    end
end

local symbol = P(false)
do
    -- Ordered by decreasing length, to prioritize the longest match.
    local strs = "... .. // << >> == ~= <= >= :: -> + - * / % ^ & | ~ # < > = ( ) [ ] { } ; , . :"
    for s in string.gmatch(strs, "%S+") do
        symbol = symbol + P(s)
    end
end

-----------------------------

local Lexer = util.Class()

function Lexer:init(file_name, input)
    self.file_name = file_name  -- Source code file name
    self.input     = input      -- Source code string (entire file)
    self.pos       = 1          -- Absolute position in the input
    self.line      = 1          -- Line number for error messages
    self.col       = 1          -- Column number for error messages
    self.matched   = false      -- Last matched substring
end

function Lexer:loc()
    return Location.new(self.file_name, self.line, self.col, self.pos)
end

-- If the given pattern matches, move the lexer forward and set self.matched.
-- The pattern can be either an LPEG pattern or a literal string.
local pattern_cache = {}
function Lexer:try(pat)
    if type(pat) == "string" then
        if not pattern_cache[pat] then pattern_cache[pat] = lpeg.P(pat) end
        pat = pattern_cache[pat]
    end
    assert(lpeg.type(pat) == "pattern")

    local new_pos = pat:match(self.input, self.pos)
    if new_pos then
        self.matched = string.sub(self.input, self.pos, new_pos - 1)
        local i = 1
        while true do
            local j = find_newline:match(self.matched, i)
            if not j then break end
            self.line = self.line + 1
            self.col  = 1
            i = j
        end
        self.col = self.col + #self.matched - i + 1
        self.pos = new_pos
        return true
    else
        return false
    end
end

function Lexer:read_short_string(delimiter)
    local parts = {}
    while true do
        if self:try(string_delimiter) then
            if self.matched == delimiter then
                break
            else
                table.insert(parts, self.matched)
            end

        elseif self:try(string_content) then
            table.insert(parts, self.matched)

        elseif self:try("\\") then
            if self:try(newline)
                then table.insert(parts, "\n")

            elseif self:try(string_dec_number) then
                local n = assert(tonumber(self.matched, 10))
                if n < 256 then
                    table.insert(parts, string.char(n))
                else
                    return false, "decimal escape sequence too large"
                end

            elseif self:try("x") then
                if self:try(string_hex_number) and #self.matched == 2 then
                    local n = assert(tonumber(self.matched, 16))
                    table.insert(parts, string.char(n))
                else
                    return false, "hexadecimal digit expected"
                end

            elseif self:try("u") then
                if not self:try("{") then
                    return false, "missing '{'"
                end
                if not self:try(string_u_number) then
                    return false, "hexadecimal digit expected"
                end
                local n = tonumber(self.matched, 16)
                if #self.matched > 8 or n >= 0x7fffffff then
                    return false, "UTF-8 value too large"
                end
                if not self:try("}") then
                    return false, "missing '}'"
                end

                table.insert(parts, utf8.char(n))

            elseif self:try("z") then
                self:try(space)

            elseif self:try(one_char) then
                local s = string_escapes[self.matched]
                if s then
                    table.insert(parts, s)
                else
                    return false, string.format("invalid escape sequence '\\%s'", self.matched)
                end
            else
                return false, "unfinished string"
            end

        else
            return false, "unfinished string"
        end
    end
    return table.concat(parts)
end

function Lexer:read_long_string(delimiter_size, what)
    local firstline = self.line
    local close = "]" .. string.rep("=", delimiter_size) .. "]"

    self:try(newline)
    local parts = {}
    while not self:try(close) do
        if self:try(longstring_content) then
            table.insert(parts, self.matched)
        else
            return false, string.format("unfinished %s (starting at line %d)", what, firstline)
        end
    end
    return table.concat(parts)
end

function Lexer:_next()
    if self:try(space) then
        return "SPACE"

    elseif self:try("--") then
        if self:try(longstring_open) then
            local s, err = self:read_long_string(#self.matched-2, "long comment")
            if not s then return false, err end
            return "COMMENT", s
        else
            self:try(comment_line)
            return "COMMENT", self.matched
        end

    elseif self:try(string_delimiter) then
        local s, err = self:read_short_string(self.matched)
        if not s then return false, err end
        return "STRING", s

    elseif self:try(longstring_open) then
        local s, err = self:read_long_string(#self.matched-2, "long string")
        if not s then return false, err end
        return "STRING", s

    elseif self:try(possible_number) then
        local n = tonumber(self.matched)
        if n then
            return "NUMBER", n
        else
            return false, string.format("malformed number near '%s'", self.matched)
        end

    elseif self:try(symbol) then -- Must try this after numbers, because of '.'
        return self.matched

    elseif self:try(identifier) then
        if is_keyword[self.matched] then
            return self.matched
        else
            return "NAME", self.matched
        end

    elseif self:try(one_char) then
        local what = (string.match(self.matched, "%g")
            and string.format("'%s'", self.matched)
            or  string.format("<\\%d>", string.byte(self.matched)))
        return false, string.format("unexpected symbol near %s", what)

    else
        return "EOF"
    end
end

-- Get the next token, ignoring whitespace and comments
--
-- Success: returns a table containing token name, semantic value, start location
-- Failure: returns false, error message
function Lexer:next()

    local loc, name, value, end_pos
    repeat
        loc = self:loc()
        name, value = self:_next()
        end_pos = self.pos - 1
        if not name then
            return false, value
        end
    until name ~= "SPACE"

    return {
        name = name,
        value = value,
        loc = loc,
        end_pos = end_pos,
    }
end

return Lexer
