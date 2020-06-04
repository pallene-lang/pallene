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
    }
}

builtins.modules = {
    io = T.Table {
        write = T.Function({ T.String() }, {}),
    },
    math = T.Table {
        sqrt = T.Function({ T.Float() }, { T.Float() }),
    },
    string = T.Table {
        char = T.Function({ T.Integer() }, { T.String() }),
        sub = T.Function({ T.String(), T.Integer(), T.Integer() }, { T.String() }),
    }
}

return builtins
