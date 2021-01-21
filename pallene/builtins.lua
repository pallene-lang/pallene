-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local types = require "pallene.types"
local T = types.T

local builtins = {}

local ipairs_itertype = T.Function({T.Any(), T.Any()}, {T.Any(), T.Any()})

builtins.functions = {
    ["type"] = T.Function({ T.Any() }, { T.String() }),
    ["io.write"] = T.Function({ T.String() }, {}),
    ["math.sqrt"] = T.Function({ T.Float() }, { T.Float() }),
    ["string.char"] = T.Function({ T.Integer() }, { T.String() }),
    ["string.sub"] = T.Function({ T.String(), T.Integer(), T.Integer() }, { T.String() }),
    ["tostring"] = T.Function({ T.Any() }, { T.String() }),
    ["ipairs"] = T.Function({T.Array(T.Any())}, {ipairs_itertype, T.Any(), T.Any()})
}

builtins.modules = {
    io = true,
    math = true,
    string = true
}

return builtins
