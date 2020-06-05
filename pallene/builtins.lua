-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local types = require "pallene.types"
local T = types.T

local builtins = {}

builtins.functions = {
    tofloat = {
        name = "tofloat",
        typ = T.Function({ T.Integer() }, { T.Float() }),
    },
    type = {
        name = "type",
        typ = T.Function({ T.Any() }, { T.String() })
    },
    ["io.write"] = {
        name = "io.write",
        typ = T.Function({ T.String() }, {})
    },
    ["math.sqrt"] = {
        name = "math.sqrt",
        typ = T.Function({ T.Float() }, { T.Float() }),
    },
    ["string_.char"] = {
        name = "string_.char",
        typ = T.Function({ T.Integer() }, { T.String() })
    },
    ["str.sub"] = {
        name = "str.sub",
        typ = T.Function({ T.String(), T.Integer(), T.Integer() }, { T.String() }),
    }
}

builtins.modules = {
    io = true,
    math = true,
    str = true
}

return builtins
