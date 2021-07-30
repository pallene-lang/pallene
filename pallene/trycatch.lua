-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local trycatch = {}

local util = require "pallene.util"

-- Getting good stack traces can be tricky if we want to be able to re-raise an exception, which
-- happens when we have a try-catch pattern that only wants to catch some of the exceptions. If we
-- don't do anything, then it will show the stack trace from the point where the exception is
-- re-raised instead of the original stack trace. Another solution that is sometimes recommended is
-- to call debug.traceback and then include that inside the error string. However, the problem is
-- that Lua will still add the stack trace for the time that the exception is re-raised, resulting
-- in two stack traces being shown.
--
-- Our workaround is to use a custom exception datatype. When the error object is not a string, Lua
-- does not automatically add the second stack trace to the end. It only calls tostring, which gives
-- us more control on what is displayed. This exception datatype also keeps track of the original
-- stack trace, meaning that it can be re-raised without messing up the stack.
--
-- Example usage:
--
--    local ok, err = trycatch.pcall(function() ...  end)
--    if not ok then
--        error(err)
--    end

local Exception = util.Class()

function Exception:init(err, stack_trace)
    self.err = err
    self.stack_trace = stack_trace
end

function Exception:__tostring()
    return tostring(self.err) .. self.stack_trace
end

---

local function msg_handler(msg)
    local stack_trace = debug.traceback("", 2)
    return Exception.new(msg, stack_trace)
end

function trycatch.pcall(fn, ...)
    return xpcall(fn, msg_handler, ...)
end

return trycatch
