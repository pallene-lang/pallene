rockspec_format = "3.0"
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
   "lua == 5.4",
   "lpeg >= 1.0",
   "argparse >= 0.7.0",
   "pallene-tracer >= 0.5.0a"
}
external_dependencies = {
   PTRACER = {
      header = "ptracer.h",
   }
}
build = {
   type = "builtin",
}
test = {
   type = "busted"
}
