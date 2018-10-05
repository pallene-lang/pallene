local ast = require "pallene.ast"

return {
    io_write     = ast.Toplevel.Builtin(false, "io.write"),
    table_insert = ast.Toplevel.Builtin(false, "table.insert"),
    table_remove = ast.Toplevel.Builtin(false, "table.remove"),
}
