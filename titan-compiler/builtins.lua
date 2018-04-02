local ast = require "titan-compiler.ast"

return {
    table_insert = ast.Toplevel.Builtin(false, "table.insert"),
    table_remove = ast.Toplevel.Builtin(false, "table.remove"),
}
