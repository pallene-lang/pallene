-- Copyright (c) 2024, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local another_module = require 'spec.traceback.module_lua.another_module'
local pallene = require 'spec.traceback.module_lua.module_lua'

function _G.lua_1()
    pallene.pallene_1(_G.lua_2)
end

function _G.lua_2()
    pallene.pallene_2(_G.lua_3, 33, 79)
end

function _G.lua_3(sum)
    print("The summation is: ", sum)

    error "Any normal error from Lua!"
end

-- Should be local.
-- Making it global so that it is visible in the traceback.
function _G.wrapper()
    another_module.call_lua_callback(_G.lua_1)
end

xpcall(_G.wrapper, _G.pallene_tracer_debug_traceback)
