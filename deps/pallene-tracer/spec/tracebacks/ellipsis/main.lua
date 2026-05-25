-- Copyright (c) 2024, The Pallene Developers
-- Pallene Tracer is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local module = require "spec.tracebacks.ellipsis.module"

function lua_fn()
    module.module_fn(lua_fn)
end

lua_fn()
