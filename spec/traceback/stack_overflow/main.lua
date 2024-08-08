-- Copyright (c) 2024, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local so = require "spec.traceback.stack_overflow.stack_overflow"

-- luacheck: globals please_dont_overflow
function please_dont_overflow()
    so.no_overflow(please_dont_overflow)
end

please_dont_overflow()
