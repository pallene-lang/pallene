# Titan
[![Build Status](https://travis-ci.org/titan-lang/titan-v0.svg?branch=master)](https://travis-ci.org/titan-lang/titan-v0)
[![Coverage Status](https://codecov.io/gh/titan-lang/titan-v0/coverage.svg?branch=master)](https://codecov.io/gh/titan-lang/titan-v0/branch/master)

Titan is a new programming language, designed to be a statically-typed,
ahead-of-time compiled sister language to [Lua](http://www.lua.org). It is an
application programming language with a focus on performance.

This repository contains the initial prototype
of the Titan compiler. It compiles a single Titan module
to C code in the [artisanal style](https://github.com/titan-lang/artisanal-titan).
The syntax is a subset of Lua syntax, plus types, and is specified in `titan-v0.ebnf`.

# Requirements for running the compiler

1. [Lua](http://www.lua.org/) >= 5.3.0
2. [LPegLabel](https://github.com/sqmedeiros/lpeglabel) >= 1.0.0
3. [inspect](https://github.com/kikito/inspect.lua) >= 3.1.0
4. [argparse](https://github.com/mpeterv/argparse) >= 0.5.0

You need to build the Lua interpreter in the `lua` folder with `MYCFLAGS=-fPIC`,
or `titanc` will not be able to build any Titan code.

# Install

Titan must be installed in a standard location;
[LuaRocks](http://luarocks.org) will do this, and will also install all dependencies automatically.

        $ [install luarocks]
        $ luarocks install titan-lang-scm-1.rockspec

# Usage

        $ titanc [options] <input>

If everything is all right with your `.titan` program this will generate an `.so`
file that you can `require` from Lua. You can call from Lua any functions that
you have defined.

# Compiler options

        --print-ast                     Print the AST.
        --print-types                   Print the AST with types.
        -o <output>, --output <output>  Output file.
        -h, --help                      Show this help message and exit.
