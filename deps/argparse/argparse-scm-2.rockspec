package = "argparse"
version = "scm-2"
source = {
   url = "git+https://github.com/luarocks/argparse.git"
}
description = {
   summary = "A feature-rich command-line argument parser",
   detailed = "Argparse supports positional arguments, options, flags, optional arguments, subcommands and more. Argparse automatically generates usage, help, and error messages, and can generate shell completion scripts.",
   homepage = "https://github.com/luarocks/argparse",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1, < 5.5"
}
build = {
   type = "builtin",
   modules = {
      argparse = "src/argparse.lua"
   }
}
