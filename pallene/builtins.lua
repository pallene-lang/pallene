-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local types = require "pallene.types"
local T = types.T

local builtins = {}

-- TODO: It will be easier to read this is we could write down the types using the normal grammar

local ipairs_itertype = T.Function({T.Any(), T.Any()}, {T.Any(), T.Any()})

builtins.functions = {
    type     = T.Function({ T.Any() }, { T.String() }),
    tostring = T.Function({ T.Any() }, { T.String() }),
    ipairs   = T.Function({T.Array(T.Any())}, {ipairs_itertype, T.Any(), T.Any()})
}

builtins.modules = {
    io = {
        write = T.Function({ T.String() }, {}),
    },
    math = {
        abs  = T.Function({ T.Float() }, { T.Float() }),
        exp  = T.Function({ T.Float() }, { T.Float() }),
        ln   = T.Function({ T.Float() }, { T.Float() }),
        log  = T.Function({ T.Float(), T.Float() }, { T.Float() }),
        pow  = T.Function({ T.Float(), T.Float() }, { T.Float() }),
        sqrt = T.Function({ T.Float() }, { T.Float() }),
    },
    string = {
        char = T.Function({ T.Integer() }, { T.String() }),
        sub  = T.Function({ T.String(), T.Integer(), T.Integer() }, { T.String() }),
    },
}

return builtins
