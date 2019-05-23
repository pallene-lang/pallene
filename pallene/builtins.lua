local ast = require "pallene.ast"
local location = require "pallene.location"
local types = require "pallene.types"

local builtins = {}

for _, lua_name in ipairs({"io.write", "table.insert", "table.remove"}) do
    local pallene_name = string.gsub(lua_name, "%.", "_")
    local loc = location.new("(builtin)", 0,0) -- (never shown to user)

    local obj = ast.Toplevel.Builtin(loc, lua_name)
    obj._type = types.T.Builtin(obj)

    builtins[pallene_name] =  obj
end

return builtins
