-- Copyright (c) 2024, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local function call_lua_callback(callback)
    callback()
end

return {
    call_lua_callback = call_lua_callback
}
