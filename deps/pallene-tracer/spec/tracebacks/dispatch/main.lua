-- Copyright (c) 2024, The Pallene Developers
-- Pallene Tracer is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local module = require "spec.tracebacks.dispatch.module"

function lua_callee_1()
    module.module_fn_2()
end

module.module_fn_1(lua_callee_1)
