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
local longstring_content = RE".[^]]*"

local hex_number = RE"[0-9A-Fa-f]"

local string_delimiter  = RE"[\"\']"
local string_content    = RE"[^\n\r]"
local string_hex_number = RE"[0-9A-Fa-f][0-9A-Fa-f]"
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
    self.old_pos   = false      -- Absolute position of last matched substring
end

function Lexer:loc()
    return Location.new(self.file_name, self.line, self.col, self.pos)
end

-- If the given pattern matches, move the lexer forward.
-- If it doesn't match, unset old_pos.
-- The pattern can be either an LPEG pattern or a literal string.
local pattern_cache = {}
function Lexer:try(pat)
    if type(pat) == "string" then
        if not pattern_cache[pat] then pattern_cache[pat] = lpeg.P(pat) end
        pat = pattern_cache[pat]
    end
    assert(lpeg.type(pat) == "pattern")

    local old_pos = self.pos
    local new_pos = pat:match(self.input, self.pos)
    if new_pos then
        local i = old_pos
        while true do
            local j = find_newline:match(self.input, i)
            if not j or j > new_pos then break end
            self.line = self.line + 1
            self.col  = 1
            i = j
        end
        self.old_pos = old_pos
        self.pos = new_pos
        self.col = self.col + (new_pos - i)
        return true
    else
        self.old_pos = false
        return false
    end
end

-- The substring for the last thing found by Lexer:try()
function Lexer:matched()
    assert(self.old_pos)
    return string.sub(self.input, self.old_pos, self.pos - 1)
end

function Lexer:read_short_string(delimiter)
    local parts = {}
    while not self:try(delimiter) do
        if self:try("\\") then
            if self:try(newline)
                then table.insert(parts, "\n")

            elseif self:try(string_dec_number) then
                local n = assert(tonumber(self:matched(), 10))
                if n < 256 then
                    table.insert(parts, string.char(n))
                else
                    return false, "decimal escape sequence too large"
                end

            elseif self:try("x") then
                if self:try(string_hex_number) then
                    local n = assert(tonumber(self:matched(), 16))
                    table.insert(parts, string.char(n))
                else
                    self:try(hex_number) -- possibly advance error location
                    return false, "hexadecimal digit expected"
                end

            elseif self:try("u") then
                if not self:try("{") then
                    return false, "missing '{'"
                end
                if not self:try(string_u_number) then
                    return false, "hexadecimal digit expected"
                end
                local s = self:matched()
                local n = tonumber(s, 16)
                if #s > 8 or n >= 0x7fffffff then
                    return false, "UTF-8 value too large"
                end
                if not self:try("}") then
                    return false, "missing '}'"
                end

                table.insert(parts, utf8.char(n))

            elseif self:try("z") then
                self:try(space)

            elseif self:try(one_char) then
                local s = self:matched()
                local c = string_escapes[s]
                if c then
                    table.insert(parts, c)
                else
                    return false, string.format("invalid escape sequence '\\%s'", s)
                end
            else
                return false, "unfinished string"
            end

        elseif self:try(string_content) then
            table.insert(parts, self:matched())

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
    local first_pos = self.pos
    local last_pos  = self.pos

    while not self:try(close) do
        if self:try(longstring_content) then
            last_pos = self.pos
        else
            return false, string.format("unfinished %s (starting at line %d)", what, firstline)
        end
    end

    return string.sub(self.input, first_pos, last_pos - 1)
end

function Lexer:_next()
    if self:try(space) then
        return "SPACE"

    elseif self:try("--") then
        if self:try(longstring_open) then
            local len = self.pos - self.old_pos - 2
            local s, err = self:read_long_string(len, "long comment")
            if not s then return false, err end
            return "COMMENT", s
        else
            self:try(comment_line)
            return "COMMENT", self:matched()
        end

    elseif self:try(string_delimiter) then
        local s, err = self:read_short_string(self:matched())
        if not s then return false, err end
        return "STRING", s

    elseif self:try(longstring_open) then
        local len = self.pos - self.old_pos - 2
        local s, err = self:read_long_string(len, "long string")
        if not s then return false, err end
        return "STRING", s

    elseif self:try(possible_number) then
        local s = self:matched()
        local n = tonumber(s)
        if n then
            return "NUMBER", n
        else
            return false, string.format("malformed number near '%s'", s)
        end

    elseif self:try(symbol) then -- Must try this after numbers, because of '.'
        return self:matched()

    elseif self:try(identifier) then
        local name = self:matched()
        if is_keyword[name] then
            return name
        else
            return "NAME", name
        end

    elseif self:try(one_char) then
        local c = self:matched()
        local what = (string.match(c, "%g")
            and string.format("'%s'", c)
            or  string.format("<\\%d>", string.byte(c)))
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
    until name ~= "SPACE" and name ~= "COMMENT"

    return {
        name = name,
        value = value,
        loc = loc,
        end_pos = end_pos,
    }
end

return Lexer
