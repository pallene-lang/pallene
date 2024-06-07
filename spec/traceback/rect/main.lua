-- Copyright (c) 2024, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local rect = require 'spec.traceback.rect.rect'

-- Should be local.
-- Making it global so that it is visible in the traceback.
function _G.wrapper()
    print(rect.area { width = "Huh, gotcha!", height = 16.0 })
end

xpcall(_G.wrapper, _G.pallene_tracer_debug_traceback)
