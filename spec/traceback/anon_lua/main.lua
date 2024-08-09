-- Copyright (c) 2024, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local anon = require "spec.traceback.anon_lua.anon_lua"

anon.call_anon_lua_fn(function()
    error "Error from an anonymous Lua fn!"
end)
