package = "titan"
version = "dev-1"
source = {
   url = "git+https://github.com/titan-lang/titan"
}
description = {
   summary = "Initial prototype of the Titan compiler",
   detailed = [[
      Initial prototype of the Titan compiler.
      This is a proof-of-concept, implementing a subset of
      the Titan language.
   ]],
   homepage = "http://github.com/titan-lang/titan",
   license = "MIT"
}
dependencies = {
   "lua ~> 5.3",
   "lpeglabel >= 1.5.0",
   "inspect >= 3.1.0",
   "argparse >= 0.5.0",
   "luafilesystem >= 1.7.0"
}
build = {
   type = "builtin",
   modules = {
      ["titan-compiler.ast"] = "titan-compiler/ast.lua",
      ["titan-compiler.checker"] = "titan-compiler/checker.lua",
      ["titan-compiler.coder"] = "titan-compiler/coder.lua",
      ["titan-compiler.driver"] = "titan-compiler/driver.lua",
      ["titan-compiler.lexer"] = "titan-compiler/lexer.lua",
      ["titan-compiler.location"] = "titan-compiler/location.lua",
      ["titan-compiler.parser"] = "titan-compiler/parser.lua",
      ["titan-compiler.pretty"] = "titan-compiler/pretty.lua",
      ["titan-compiler.symtab"] = "titan-compiler/symtab.lua",
      ["titan-compiler.syntax_errors"] = "titan-compiler/syntax_errors.lua",
      ["titan-compiler.typedecl"] = "titan-compiler/typedecl.lua",
      ["titan-compiler.types"] = "titan-compiler/types.lua",
      ["titan-compiler.util"] = "titan-compiler/util.lua",
   },
   install = {
      bin = {
         "titanc"
      }
   }
}
