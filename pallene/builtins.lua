local ast = require "pallene.ast"
local location = require "pallene.location"
local types = require "pallene.types"

local builtins = {}

for lua_name, typ in pairs({
    ["io.write"]     = types.T.Function({types.T.String()}, {}),
    ["table.insert"] = types.T.Function({types.T.Array(types.T.Value()), types.T.Value()}, {}),
    ["table.remove"] = types.T.Function({types.T.Array(types.T.Value())}, {}),
    ["tofloat"]      = types.T.Function({types.T.Integer()}, {types.T.Float()}),
}) do
    local pallene_name = string.gsub(lua_name, "%.", "_")
    local loc = location.new("(builtin)", 0,0) -- (never shown to user)

    local obj = ast.Toplevel.Builtin(loc, lua_name)
    obj._type = typ

    builtins[pallene_name] =  obj
end

return builtins
