-- Copyright (c) 2024, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local pallene = require 'spec.traceback.depth_recursion.depth_recursion'

function lua_fn(depth)
    if depth == 0 then
        error "Depth reached 0!"
    end

    pallene.pallene_fn(lua_fn, depth - 1)
end

local function wrapper()
    lua_fn(10)
end

xpcall(wrapper, pallene_tracer_debug_traceback)
