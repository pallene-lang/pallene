package = "pallene"
version = "dev-1"
source = {
   url = "git+https://github.com/pallene-lang/pallene"
}
description = {
   summary = "Initial prototype of the Pallene compiler",
   detailed = [[
      Initial prototype of the Pallene compiler.
   ]],
   homepage = "http://github.com/pallene-lang/pallene",
   license = "MIT"
}
dependencies = {
   "lua ~> 5.3",
   "lpeglabel >= 1.5.0",
   "inspect >= 3.1.0",
   "argparse >= 0.5.0",
   "luafilesystem >= 1.7.0",
   "chronos >= 0.2",
}
build = {
   type = "builtin",
   modules = {
      ["pallene.ast"] =            "pallene/ast.lua",
      ["pallene.ast_iterator"] =   "pallene/ast_iterator.lua",
      ["pallene.builtins"] =       "pallene/builtins.lua",
      ["pallene.c_compiler"] =     "pallene/c_compiler.lua",
      ["pallene.checker"] =        "pallene/checker.lua",
      ["pallene.coder"] =          "pallene/coder.lua",
      ["pallene.lexer"] =          "pallene/lexer.lua",
      ["pallene.location"] =       "pallene/location.lua",
      ["pallene.parser"] =         "pallene/parser.lua",
      ["pallene.pretty"] =         "pallene/pretty.lua",
      ["pallene.scope_analysis"] = "pallene/scope_analysis.lua",
      ["pallene.symtab"] =         "pallene/symtab.lua",
      ["pallene.syntax_errors"] =  "pallene/syntax_errors.lua",
      ["pallene.typedecl"] =       "pallene/typedecl.lua",
      ["pallene.types"] =          "pallene/types.lua",
      ["pallene.upvalues"] =       "pallene/upvalues.lua",
      ["pallene.util"] =           "pallene/util.lua",
   },
   install = {
      bin = {
         "pallenec"
      }
   }
}
