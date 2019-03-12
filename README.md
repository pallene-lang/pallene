# Pallene
[![Build Status](https://travis-ci.org/pallene-lang/pallene.svg?branch=master)](https://travis-ci.org/pallene-lang/pallene)

Pallene is a statically typed, ahead-of-time-compiled sister language to
[Lua](https://www.lua.org), with a focus on performance. It is also a friendly
fork of the [Titan](https://www.github.com/titan-lang/titan).

Pallene is intended for writing performance sensitive code that interacts with
Lua, a space that is currently filled by C modules and by LuaJIT. Compared to
C, Pallene should offer better support for interacting with Lua data types,
bypassing the unfriendly syntax and performance overhead of the Lua-C API.
Compared to LuaJIT, Pallene aims to offer more predictable run-time performance.

## Building the Pallene Compiler

In order to use this source distribution of the Pallene compiler, you need to
install its Lua library dependencies and compile its run-time library.

### Installing dependencies

The easiest way to install the dependencies for the Pallene compiler is through
the [LuaRocks](http://luarocks.org) package manager:

```sh
$ luarocks install --local --only-deps pallene-dev-1.rockspec
```

If you want to use Pallene on Linux we also recommend installing the `readline`
library:

```sh
$ sudo apt install libreadline-dev   # for Ubuntu & Debian-based distros
$ sudo dnf install readline-devel # for Fedora and OpenSUSE
```

### Compiling the runtime libraries

Pallene must be run against a custom-built version of the Lua interpreter, as
well as the Pallene runtime library. Both of these are written in C and must be
compiled before the Pallene compiler can be used.

These two components can be built through the Makefile we provide. The command
to be used depends on your operating system:

```sh
make linux-readline # for Linux
make macosx         # for MacOS
```

## Usage

To compile a `foo.pallene` file to a `foo.so` module call `pallenec` as follows.

Note: Your current working directory must be the root of this repository, due to 
[Bug #16](https://github.com/pallene-lang/pallene/issues/16).


```sh
$ ./pallenec foo.pallene
```

To run Pallene, you must currently use the bundled version of the Lua
interpreter (again, see [Bug #16](https://github.com/pallene-lang/pallene/issues/16)).

```sh
$ ./lua/src/lua -l foo
```

For more compiler options, see `./pallenec --help`

## Developing Pallene

If you want to develop Pallene, it is helpful to know how to configure your
editor to preserve our style standards, and to know how to run the test suite.

### Configuring your editor

The easiest way to make sure you are indenting things correctly is to install
the [EditorConfig](https://editorconfig.org/) plugin in your favorite
text editor.

THis project uses 4 spaces for indentation, and tries to limit each line to at
most 80 columns.

### Using a linter.

We use [Luacheck](https://github.com/mpeterv/luacheck) to lint our Lua source
code. We recommend running it at least once before each pull-request or, even
better, integrating it to your text editor. For instructions on how to install
and use Luacheck, see our `.luacheckrc` file.

### Running the test suite

We use Busted to run our test suite. It can be installed using LuaRocks:

```sh
$ luarocks install --local busted
```

To run the test suite, just run busted on the root directory of this repository:

```sh
$ busted                       # Run all tests
$ busted spec/parser_spec.lua  # Run just one of the test suite files
```
### Running the benchmarks suite

To run of the benchmarks in the benchmarks directory, tun the `benchmarks/run`
script from the root project directory:

```sh
./benchmarks/run benchmarks/sieve/pallene.pallene
```

By default, the benchmark runner just outputs the running time, as measured by
`/usr/bin/time`, but it also supports other measurements. For example,
`--mode=perf` shows perf output and `--mode=none` shows the stdout produced by
the benchmark, withot measuring anything.

```sh
./benchmarks/run benchmarks/sieve/pallene.pallene --mode=none
```

To run benchmarks with LuaJIT, use the `--lua` option:

```sh
./benchmarks/run benchmarks/sieve/lua.lua --lua=luajit
```
