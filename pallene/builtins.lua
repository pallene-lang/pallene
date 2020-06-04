-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local types = require "pallene.types"
local T = types.T

local builtins = {}

builtins.functions = {
    io_write = {
        name = "io.write",
        typ = T.Function({ T.String() }, {})
    },
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
    }
}

builtins.modules = {
    io = {

    }
}

return builtins
