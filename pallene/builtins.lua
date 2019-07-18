local types = require "pallene.types"

local builtins = {}

for lua_name, typ in pairs({
    ["io.write"]     = types.T.Function({types.T.String()}, {}),
    ["tofloat"]      = types.T.Function({types.T.Integer()}, {types.T.Float()}),
}) do
    local pallene_name = string.gsub(lua_name, "%.", "_")
    builtins[pallene_name] = {
        name = lua_name,
        typ = typ,
    }
end

return builtins
