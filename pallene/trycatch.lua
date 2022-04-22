-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local trycatch = {}

local util = require "pallene.util"

-- Object-based error handling
-- ===========================
--
-- Lua encourages programmers to use strings for error messages, but that doesn't work well if we
-- want to implement a try-catch pattern. Firstly, each time that we re-raise a string exception,
-- Lua adds another stack trace at the end. Secondly, if the exception is a string then it is hard
-- to tell what kind of exception it is.
--
-- Our solution is to wrap every exception in a custom Exception data type. Even if this exception
-- is re-raised, it will still show the original stack trace. These exception objects also have an
-- exception tag saying what kind of exception it is.
--
-- Example usage
-- -------------
--
--    local ok, ret = trycatch.pcall(function()
--         trycatch.error("xyz", "message")
--    end)
--    if ok then
--        -- success
--        return ret
--    else
--        if ret.tag == "xyz" then
--            -- catch "xyz" exception
--            return ret.msg
--        else
--            -- re-raise other exceptions
--            error(ret)
--        end
--    end

local Exception = util.Class()

function Exception:init(tag, msg, level)
    self.tag = tag
    self.msg = msg
    self.stack_trace = debug.traceback(tostring(msg), level)
end

function Exception:__tostring()
    return self.stack_trace
end

---

local function msg_handler(msg)
    if getmetatable(msg) == Exception then
        return msg
    else
        return Exception.new(false, msg, 3)
    end
end

function trycatch.pcall(fn, ...)
    return xpcall(fn, msg_handler, ...)
end

function trycatch.error(tag, msg, level)
    level = level or 1
    error(Exception.new(tag, msg, level+3))
end

return trycatch
