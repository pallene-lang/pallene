# Titan
[![Build Status](https://travis-ci.org/titan-lang/titan.svg?branch=master)](https://travis-ci.org/titan-lang/titan)
[![Coverage Status](https://codecov.io/gh/titan-lang/titan/coverage.svg?branch=master)](https://codecov.io/gh/titan-lang/titan/branch/master)

Titan is a new programming language, designed to be a statically-typed,
ahead-of-time compiled sister language to [Lua](http://www.lua.org). It is an
application programming language with a focus on performance.

This repository contains the initial prototype
of the Titan compiler. It compiles a single Titan module
to C code in the [artisanal style](https://github.com/titan-lang/artisanal-titan).
The syntax is a subset of Lua syntax, plus types, and is specified in `titan-v0.ebnf`.

# Install

First you need to build and install the Lua interpreter in the `lua` folder, 
as it has the needed changes to `luaconf.h` to be able to load Titan modules. 
Apart from the changes in `luaconf.h` this interpreter is identical to Lua 5.3.4.
The `package.cpath` of this interpreter has a `/usr/local/lib/titan/5.3.4/?.so`
entry for any system-wide Titan modules.

You can install the Titan compiler itself using  [LuaRocks](http://luarocks.org)
this will also install all dependencies automatically.

        $ [install luarocks]
        $ luarocks install titan-scm-1.rockspec


# Requirements for running the compiler

1. [LPegLabel](https://github.com/sqmedeiros/lpeglabel) >= 1.0.0
2. [inspect](https://github.com/kikito/inspect.lua) >= 3.1.0
3. [argparse](https://github.com/mpeterv/argparse) >= 0.5.0


# Usage

        $ titanc [options] <input>

If everything is all right with your `.titan` program this will generate an `.so`
file that you can `require` from Lua. You can call from Lua any functions that
you have defined.

# Running the test suite

The test suite es written using Busted, which can be installed using LuaRocks:

        $ luarocks install busted

Then, you need to bulid the local copy of Lua, and run `busted` from the root directory
of this repository:

        $ cd lua
        $ make linux MYCFLAGS=-fpic
        $ cd ..
        $ busted

You may need to adapt the invocation of `make` above to your platform.

# Compiler options

        --print-ast                     Print the AST.
        --print-types                   Print the AST with types.
        -o <output>, --output <output>  Output file.
        -h, --help                      Show this help message and exit.
        
# Tentative roadmap

This is a *very* preliminary roadmap towards Titan 1.0, where everything is
subject to change, with things more likely to change the further
they are in the roadmap:

## Supported

* control structures
* integers
* floats
* booleans
* strings
* arrays
* top-level functions

## In progress

* early-bound modules

## Next

* records (structs)
* maps
* basic FFI with C (C arrays, C structs, C pointers, call C functions that take numbers and pointers as arguments)
* standard library that is a subset of Lua's standard library, built using the C FFI
* first-class functions (still only in the top-level)
* tagged variants (unions of structs with some syntax for switch/case on the tag)
* multiple assignment/multiple returns
* polymorphic functions
* for-in
* self-hosted compiler
* nested and anonymous first-class functions with proper lexical scoping (closures)
* ":" syntax sugar for records of functions
* classes with single inheritance, either Go/Java/C#/Swift-like interfaces/protocols or Haskell/Rust-like typeclasses/traits
* ":" method calls (not syntax sugar)
* operator overloading
* ...Titan 1.0!
