-- Copyright (c) 2024, The Pallene Developers
-- Pallene Tracer is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local module = require "spec.tracebacks.depth_recursion.module"

function lua_fn(depth)
    if depth == 0 then
        error "Depth reached 0!"
    end

    module.module_fn(lua_fn, depth - 1)
end

lua_fn(10)
