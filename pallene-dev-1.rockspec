rockspec_format = "3.0"
package = "pallene"
version = "dev-1"
source = {
   url = "git+https://github.com/pallene-lang/pallene"
}
description = {
   summary = "Pallene compiler",
   detailed = [[
       Compiler for Pallene, a typed and AOT-compiled companion language for Lua.

       Attention: You must use PUC-Lua 5.4.4 exactly. Pallene depends on undocumented internal Lua
       APIs which change even on minor bugfix patches. If you try to install Pallene on a different
       revision of Lua 5.4, you will get a build error]],
   homepage = "http://github.com/pallene-lang/pallene",
   license = "MIT"
}
dependencies = {
   "lua = 5.4",
   "lpeg >= 1.0",
   "inspect >= 3.1.0",
   "argparse >= 0.7.0",
}
build = {
   type = "builtin",
   modules = {
      ["pallene.assignment_conversion.lua"] = "pallene/assignment_conversion.lua",
      ["pallene.ast.lua"] = "pallene/ast.lua",
      ["pallene.builtins.lua"] = "pallene/builtins.lua",
      ["pallene.C.lua"] = "pallene/C.lua",
      ["pallene.c_compiler.lua"] = "pallene/c_compiler.lua",
      ["pallene.checker.lua"] = "pallene/checker.lua",
      ["pallene.coder.lua"] = "pallene/coder.lua",
      ["pallene.constant_propagation.lua"] = "pallene/constant_propagation.lua",
      ["pallene.driver.lua"] = "pallene/driver.lua",
      ["pallene.gc.lua"] = "pallene/gc.lua",
      ["pallene.ir.lua"] = "pallene/ir.lua",
      ["pallene.Lexer.lua"] = "pallene/Lexer.lua",
      ["pallene.Location.lua"] = "pallene/Location.lua",
      ["pallene.parser.lua"] = "pallene/parser.lua",
      ["pallene.print_ir.lua"] = "pallene/print_ir.lua",
      ["pallene.symtab.lua"] = "pallene/symtab.lua",
      ["pallene.to_ir.lua"] = "pallene/to_ir.lua",
      ["pallene.translator.lua"] = "pallene/translator.lua",
      ["pallene.trycatch.lua"] = "pallene/trycatch.lua",
      ["pallene.typedecl.lua"] = "pallene/typedecl.lua",
      ["pallene.types.lua"] = "pallene/types.lua",
      ["pallene.uninitialized.lua"] = "pallene/uninitialized.lua",
      ["pallene.util.lua"] = "pallene/util.lua",
      -- Generated files:
      ["pallene._corelib"] = "pallene/_corelib.c",
   },
   install = {
      bin = {
         "pallenec"
      }
   }
}
test = {
    type = "busted"
}
