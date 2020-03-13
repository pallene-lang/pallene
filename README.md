# Pallene
[![Build Status](https://travis-ci.org/pallene-lang/pallene.svg?branch=master)](https://travis-ci.org/pallene-lang/pallene)

Pallene is a statically typed, ahead-of-time-compiled sister language to
[Lua](https://www.lua.org), with a focus on performance. It is also a 
[friendly fork](http://lua-users.org/lists/lua-l/2018-09/msg00255.html) of the
[Titan](https://www.github.com/titan-lang/titan) language.

Pallene is intended for writing performance sensitive code that interacts with
Lua, a space that is currently filled by C modules and by LuaJIT. Compared to
C, Pallene should offer better support for interacting with Lua data types,
bypassing the unfriendly syntax and performance overhead of the Lua-C API.
Compared to LuaJIT, Pallene aims to offer more predictable run-time performance.

## Building the Pallene Compiler

In order to use this source distribution of the Pallene compiler, you need to
install its Lua library dependencies and compile its run-time library.

### Prerequisites

Pallene requires Lua 5.3 to be installed on your system. You can either install it
from a package manager (such as apt) or build it from the source code. You can download
the source code of Lua 5.3 from [https://github.com/luarocks/luarocks](https://github.com/luarocks/luarocks).

After Lua 5.3 is installed, download the source code of LuaRocks from 
[https://github.com/luarocks/luarocks](https://github.com/luarocks/luarocks).

As of now, LuaRocks is configured to use Lua 5.1 by default. However, Pallene
requires Lua 5.3 to run. Therefore, please configure LuaRocks to use Lua 5.3.
You can use the following command to configure LuaRocks to use Lua 5.3 when
compiling it:
`./configure --lua-version=5.3`

### Installing dependencies

The easiest way to install the dependencies for the Pallene compiler is through
the [LuaRocks](http://luarocks.org) package manager:

```sh
$ luarocks install --local --only-deps pallene-dev-1.rockspec
```



If you use the --local flag when installing packages from Luarocks, you may
also need to configure the appropriate environment variables on your terminal configuration file.
If you are using bash you can do (as stated in `luarocks --help path`):
```sh
$ echo 'eval `luarocks path`' >> ~/.bashrc 
```
For further information, consult the [Luarocks documentation](https://github.com/luarocks/luarocks/wiki/path).

If you want to use Pallene on Linux we also recommend installing the `readline`
library:

```sh
$ sudo apt install libreadline-dev # for Ubuntu & Debian-based distros
$ sudo dnf install readline-devel  # for Fedora
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

To compile a `foo.pln` file to a `foo.so` module call `pallenec` as follows.

Note: Your current working directory must be the root of this repository, due to 
[Bug #16](https://github.com/pallene-lang/pallene/issues/16).


```sh
$ ./pallenec foo.pln
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

This project uses 4 spaces for indentation, and tries to limit each line to at
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

If you are debugging an unhandled exception in a test case, there are some
helpful flags that you can pass to the busted command:

Flag             | Effect
---------------- | --------------------------------------------------------
busted -v        | Verbose output, including the stack trace
busted --no-k    | Stop running tests after the first error
busted -o gtest  | Changes the output formatting.<br>This may be clearer if you are using print statements for debugging.

### Running the benchmarks suite

To run of the benchmarks in the benchmarks directory, run the `benchmarks/run`
script from the root project directory:

```sh
./benchmarks/run benchmarks/sieve/pallene.pln
```

By default, the benchmark runner just outputs the running time, as measured by
`/usr/bin/time`, but it also supports other measurements. For example,
`--mode=perf` shows perf output and `--mode=none` shows the stdout produced by
the benchmark, without measuring anything.

```sh
./benchmarks/run benchmarks/sieve/pallene.pln --mode=none
```

To run Pallene's benchmarks you need to have /usr/bin/time installed in your system.
Some Linux distributions may have only the Bash time builtin function but not the /usr/bin/time executable.
If that is the case you will need to install time with $ sudo apt install time or equivalent.

To run benchmarks with LuaJIT, use the `--lua` option:

```sh
./benchmarks/run benchmarks/sieve/lua.lua --lua=luajit
```

