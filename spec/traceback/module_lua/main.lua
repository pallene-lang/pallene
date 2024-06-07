-- Copyright (c) 2024, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local another_module = require 'spec.traceback.module_lua.another_module'
local pallene = require 'spec.traceback.module_lua.module_lua'

function lua_1()
    pallene.pallene_1(lua_2)
end

function lua_2()
    pallene.pallene_2(lua_3, 33, 79)
end

function lua_3(sum)
    print("The summation is: ", sum)

    error "Any normal error from Lua!"
end

local function wrapper()
    another_module.call_lua_callback(lua_1)
end

xpcall(wrapper, pallene_tracer_debug_traceback)
