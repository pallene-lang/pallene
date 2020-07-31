-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local lpeg = require "lpeg"
local re = require "re"
local Location = require "pallene.Location"
local util = require "pallene.util"

-----------------------------

local P  = lpeg.P
local RE = re.compile

local one_char = P(1)

local space = RE"[ \t\n\v\f\r]+"
local newline = P"\n\r" + P"\r\n" + P"\n" + P"\r" -- See inclinenumber in llex.c

local comment_line = RE"[^\n\r]*" * newline^-1

local longstring_open    = P("[") * P("=")^0 * P("[")
local longstring_close   = P("]") * P("=")^0 * P("]")
local longstring_content = (P(1) - longstring_close)^1

local string_delimiter  = RE"[\"\']"
local string_hex_number = RE"[0-9A-Fa-f][0-9A-Fa-f]"
local string_dec_number = RE"[0-9][0-9]?[0-9]?"
local string_u_number   = RE"[0-9A-Fa-f]+"
local string_content    = RE"[^\"\'\n\r\\]+"

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
        then true until while   any as boolean export float string import integer record typealias
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
    self.input     = input      -- Source code string
    self.pos       = 1          -- Absolute position in the input
    self.line      = 1          -- Line number for error messages
    self.col       = 1          -- Column number for error messages
    self.matched   = false      -- Last matched substring
end

-- If the given pattern matches, updates the lexer state and returns true. Otherwise, returns false.
-- The pattern can be either an LPEG pattern or a literal string.
local pattern_cache = {}
function Lexer:try(pat)
    if type(pat) == "string" then
        if not pattern_cache[pat] then pattern_cache[pat] = P(pat) end
        pat = pattern_cache[pat]
    end
    assert(lpeg.type(pat) == "pattern")

    local new_pos = pat:match(self.input, self.pos)
    if new_pos then
        self.matched = string.sub(self.input, self.pos, new_pos - 1)
        local i = 1
        while true do
            local j = newline:match(self.matched, i)
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
                local n = tonumber(self.matched)
                if n < 256 then
                    table.insert(parts, string.char(n))
                else
                    return false, "Decimal escape sequence is too large"
                end

            elseif self:try("x") then
                if self:try(string_hex_number) then
                    local n = assert(tonumber(self.matched, 16))
                    table.insert(parts, string.char(n))
                else
                    return false, "\\x escape sequences must have exactly two hexadecimal digits"
                end

            elseif self:try("u") then
                if not self:try("{") then
                    return false, "Expected '{' after \\u"
                end
                if not self:try(string_u_number) then
                    return false, "Expected one or more hexadecimal digits after '{'"
                end
                local n = assert(tonumber(self.matched, 16))
                if not self:try("}") then
                    return false, "Expected '}' to close the \\u escape sequence"
                end

                if n < (1<<31) then
                    table.insert(parts, utf8.char(n))
                else
                    return false, "UTF-8 value is too large"
                end

            elseif self:try("z") then
                self:try(space)

            elseif self:try(one_char) then
                local s = string_escapes[self.matched]
                if s then
                    table.insert(parts, s)
                else
                    return false, string.format("Invalid escape sequence %s", "\\"..self.matched)
                end

            else
                return false, "Unfinished escape sequence"
            end

        else
            return false, "Unclosed string"
        end
    end
    return table.concat(parts)
end

function Lexer:read_long_string(delimiter_length)
    self:try(newline)
    local parts = {}
    while true do
        if self:try(longstring_close) then
            if #self.matched == delimiter_length then
                break
            else
                table.insert(parts, self.matched)
            end

        elseif self:try(longstring_content) then
            table.insert(parts, self.matched)

        else
            return false
        end
    end
    return table.concat(parts)
end

function Lexer:_next()

    if self:try(space) then
        return "SPACE"

    elseif self:try("--") then
        if self:try(longstring_open) then
            local s = self:read_long_string(#self.matched)
            if not s then return false, "Unclosed long comment" end
        else
            self:try(comment_line)
        end
        return "COMMENT"

    elseif self:try(string_delimiter) then
        local s, err = self:read_short_string(self.matched)
        if not s then return false, err end
        return "STRING", s

    elseif self:try(longstring_open) then
        local s = self:read_long_string(#self.matched)
        if not s then return false, "Unclosed long string" end
        return "STRING", s

    elseif self:try(possible_number) then
        local n = tonumber(self.matched)
        if n then
            return "NUMBER", n
        else
            return false, string.format("Invalid numeric literal %q", self.matched)
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
        return false, string.format("Unexpected character %q", self.matched)

    else
        return "EOF"
    end
end

--
-- Get the next token, ignoring whitespace and comments
--
-- Success: returns a table containing token name, semantic value, start location
-- Failure: returns false, error message
--
function Lexer:next()
    while true do
        local loc = self:loc()
        local name, val = self:_next()
        if not name then
            return false, val
        end
        if name ~= "SPACE" and name ~= "COMMENT" then
            return { name = name, value = val, loc = loc }
        end
    end
end

function Lexer:loc()
    return Location.new(self.file_name, self.line, self.col, self.pos)
end

return Lexer
