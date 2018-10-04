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
      ["titan-compiler.ast"] =            "titan-compiler/ast.lua",
      ["titan-compiler.ast_iterator"] =   "titan-compiler/ast_iterator.lua",
      ["titan-compiler.builtins"] =       "titan-compiler/builtins.lua",
      ["titan-compiler.c_compiler"] =     "titan-compiler/c_compiler.lua",
      ["titan-compiler.checker"] =        "titan-compiler/checker.lua",
      ["titan-compiler.coder"] =          "titan-compiler/coder.lua",
      ["titan-compiler.lexer"] =          "titan-compiler/lexer.lua",
      ["titan-compiler.location"] =       "titan-compiler/location.lua",
      ["titan-compiler.parser"] =         "titan-compiler/parser.lua",
      ["titan-compiler.pretty"] =         "titan-compiler/pretty.lua",
      ["titan-compiler.scope_analysis"] = "titan-compiler/scope_analysis.lua",
      ["titan-compiler.symtab"] =         "titan-compiler/symtab.lua",
      ["titan-compiler.syntax_errors"] =  "titan-compiler/syntax_errors.lua",
      ["titan-compiler.typedecl"] =       "titan-compiler/typedecl.lua",
      ["titan-compiler.types"] =          "titan-compiler/types.lua",
      ["titan-compiler.upvalues"] =       "titan-compiler/upvalues.lua",
      ["titan-compiler.util"] =           "titan-compiler/util.lua",
   },
   install = {
      bin = {
         "pallenec"
      }
   }
}
