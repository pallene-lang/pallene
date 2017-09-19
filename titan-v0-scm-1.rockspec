package = "titan-v0"
version = "scm-1"
source = {
   url = "git+https://github.com/titan-lang/titan-v0"
}
description = {
   summary = "Initial prototype of the Titan compiler",
   detailed = [[
      Initial prototype of the Titan compiler.
      This is a proof-of-concept, implementing a subset of
      the Titan language.
   ]],
   homepage = "http://github.com/titan-lang/titan-v0",
   license = "MIT"
}
dependencies = {
   "lua ~> 5.3",
   "parser-gen >= 1.0",
   "inspect >= 3.1.0",
   "argparse >= 0.5.0",
}
build = {
   type = "builtin",
   modules = {
      ["titan-compiler.ast"] = "titan-compiler/ast.lua",
      ["titan-compiler.lexer"] = "titan-compiler/lexer.lua",
      ["titan-compiler.parser"] = "titan-compiler/parser.lua"
   },
   install = {
      bin = {
         "titanc"
      }
   }
}
