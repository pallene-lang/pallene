-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = require "pallene.util"

--
-- A datattype representing a point in a source code file
--
local Location = util.Class()

function Location:init(file_name, line, col, pos)
    self.file_name = file_name
    self.line = line
    self.col = col
    self.pos = pos
end

function Location:show_line()
    return string.format("%s:%d", self.file_name, self.line)
end

function Location:show_line_col()
    return string.format("%s:%d:%d", self.file_name, self.line, self.col)
end

function Location:__tostring()
    return string.format("%d:%d", self.line, self.col)
end

function Location:format_error(fmt, ...)
    return self:show_line_col() .. ": " .. string.format(fmt, ...)
end

return Location
