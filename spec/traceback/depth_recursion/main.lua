-- Copyright (c) 2024, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local pallene = require "spec.traceback.depth_recursion.depth_recursion"

-- luacheck: globals lua_fn
function lua_fn(depth)
    if depth == 0 then
        error "Depth reached 0!"
    end

    pallene.pallene_fn(lua_fn, depth - 1)
end

lua_fn(10)
