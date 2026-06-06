#!/usr/bin/env lua

local Parser = require "argparse"

local parser = Parser()
   :description "A testing program."
   :add_help_command()
   :require_command(false)

parser:argument "input"

parser:flag "-v" "--verbose"
   :description "Sets verbosity level."
   :target "verbosity"
   :count "0-2"

local install = parser:command "install"
   :description "Install a rock."

install:argument "rock"
   :description "Name of the rock."

install:argument "version"
   :description "Version of the rock."
   :args "?"

install:option "-f" "--from"
   :description "Fetch the rock from this server."
   :target "server"

parser:get_usage()
parser:get_help()
local args = parser:parse()

print(args.input)
print(args.verbosity)
print(args.install)
print(args.rock)
print(args.version)
print(args.server)
