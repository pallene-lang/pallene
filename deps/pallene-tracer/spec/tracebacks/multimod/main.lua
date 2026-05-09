-- Copyright (c) 2024, The Pallene Developers
-- Pallene Tracer is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local mod_a = require "spec.tracebacks.multimod.module_a"
local mod_b = require "spec.tracebacks.multimod.module_b"

function some_lua_fn()
    mod_b.another_mod_fn()
end

mod_a.some_mod_fn(some_lua_fn)
