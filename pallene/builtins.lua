-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local types = require "pallene.types"

local builtins = {}

local T = types.T

for lua_name, typ in pairs({
    ["io.write"]     = T.Function({T.String()}, {}),
    ["math.sqrt"]    = T.Function({T.Float()}, {T.Float()}),
    ["string.char"]  = T.Function({T.Integer()}, {T.String()}),
    ["string.sub"]   = T.Function({T.String(), T.Integer(), T.Integer()}, {T.String()}),
    ["tofloat"]      = T.Function({T.Integer()}, {T.Float()}),
    ["btype"]         = T.Function({T.Any()}, {T.String()}),
}) do
    local pallene_name = string.gsub(lua_name, "%.", "_")
    builtins[pallene_name] = {
        name = lua_name,
        typ = typ,
    }
end

return builtins
