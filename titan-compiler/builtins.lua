local ast = require "titan-compiler.ast"

local builtins = {}

builtins.table_insert = ast.Toplevel.Builtin(false, "table.insert")
builtins.table_remove = ast.Toplevel.Builtin(false, "table.remove")

return builtins
