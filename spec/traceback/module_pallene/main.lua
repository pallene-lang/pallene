-- Copyright (c) 2024, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local pallene = require 'spec.traceback.module_pallene.module_pallene'
local pallene_alt = require 'spec.traceback.module_pallene.module_pallene_alt'

-- luacheck: globals lua_2
function lua_2()
    error "There's an error in everyday life. Shame!"
end

-- luacheck: globals lua_1
function lua_1()
    pallene_alt.alternate_everyday_fn(lua_2)
end

-- Should be local.
-- Making it global so that it is visible in the traceback.
-- luacheck: globals wrapper
function wrapper()
    pallene.normal_everyday_fn(lua_1)
end

-- luacheck: globals pallene_tracer_debug_traceback
xpcall(wrapper, pallene_tracer_debug_traceback)
