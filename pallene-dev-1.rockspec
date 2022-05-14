package = "pallene"
version = "dev-1"
source = {
   url = "git+https://github.com/pallene-lang/pallene"
}
description = {
   summary = "Pallene compiler",
   detailed = [[
Compiler for the Pallene programming language.]],
   homepage = "http://github.com/pallene-lang/pallene",
   license = "MIT"
}
dependencies = {
   "lua >= 5.3",
   "lpeg >= 1.0",
   "inspect >= 3.1.0",
   "argparse >= 0.7.0",
}
build = {
   type = "builtin",
   modules = {
      ["pallene.assignment_conversion"] = "pallene/assignment_conversion.lua",
      ["pallene.ast"] =            "pallene/ast.lua",
      ["pallene.builtins"] =       "pallene/builtins.lua",
      ["pallene.C"] =              "pallene/C.lua",
      ["pallene.c_compiler"] =     "pallene/c_compiler.lua",
      ["pallene.checker"] =        "pallene/checker.lua",
      ["pallene.coder"] =          "pallene/coder.lua",
      ["pallene.constant_propagation"] = "pallene/constant_propagation.lua",
      ["pallene.driver"] =         "pallene/driver.lua",
      ["pallene.gc"] =             "pallene/gc.lua",
      ["pallene.ir"] =             "pallene/ir.lua",
      ["pallene.Lexer"] =          "pallene/Lexer.lua",
      ["pallene.Location"] =       "pallene/Location.lua",
      ["pallene.pallenelib"] =     "pallene/pallenelib.lua",
      ["pallene.parser"] =         "pallene/parser.lua",
      ["pallene.print_ir"] =       "pallene/print_ir.lua",
      ["pallene.symtab"] =         "pallene/symtab.lua",
      ["pallene.to_ir"] =          "pallene/to_ir.lua",
      ["pallene.translator"] =     "pallene/translator.lua",
      ["pallene.trycatch"] =       "pallene/trycatch.lua",
      ["pallene.typedecl"] =       "pallene/typedecl.lua",
      ["pallene.types"] =          "pallene/types.lua",
      ["pallene.uninitialized"] =  "pallene/uninitialized.lua",
      ["pallene.util"] =           "pallene/util.lua",
   },
   install = {
      bin = {
         "pallenec"
      }
   }
}
