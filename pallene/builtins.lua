local ast = require "pallene.ast"
local location = require "pallene.location"
local types = require "pallene.types"


local builtins = {}

-- I don't expect this to ever be shown to the end user
local loc = location.new("(builtin)", 0,0)

--
-- Builtin functions
--

builtins.io_write = ast.Toplevel.Builtin(loc, "io.write")
builtins.io_write._type = types.T.Builtin(builtins.io_write)

builtins.table_insert = ast.Toplevel.Builtin(loc, "table.insert")
builtins.table_insert._type = types.T.Builtin(builtins.table_insert)

builtins.table_remove = ast.Toplevel.Builtin(false, "table.remove")
builtins.table_remove._type = types.T.Builtin(builtins.table_remove)

return builtins
