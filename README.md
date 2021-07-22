# Pallene
[![Actions Status](https://github.com/pallene-lang/pallene/workflows/Github%20Actions%20CI/badge.svg)](https://github.com/pallene-lang/pallene/actions)

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

Before you build Pallene, you need to install a C compiler (e.g. `gcc`) and `make` on your system.
Ubuntu users can run the following commands to install these tools.
```
sudo apt update
sudo apt install build-essential
```

If you are on Linux, we also recommend that you install the Readline library.

```sh
sudo apt install libreadline-dev # for Ubuntu & Debian-based distros
sudo dnf install readline-devel  # for Fedora
```

Another optional dependency is GNU parallel, which speeds up how long it takes to run the test suite.

```sh
sudo apt install parallel # for Ubuntu & Debian-based distros
sudo dnf install parallel # for Fedora
```

Pallene requires Lua 5.3 or newer to be installed on your system.
You can either install it [from source](https://www.lua.org/ftp/) or via the package manager for your Linux distro.
If you install via the package manager then make sure to also install the Lua headers, which are often in a separate "development" package.

After Lua 5.3 is installed, download the source code of LuaRocks from
[https://github.com/luarocks/luarocks/releases](https://github.com/luarocks/luarocks/releases). Follow
the build instructions appropriate for your platform and install it on your system.

If LuaRocks is configured to use older versions of Lua, you may not be able to
install the dependencies as described in the next section. Therefore, please
configure LuaRocks to use Lua 5.3. You can use the following command to configure
LuaRocks to use Lua 5.3 when compiling it:
`./configure --lua-version=5.3`

### Installing Lua dependencies

The easiest way to install these dependencies is with the [LuaRocks](http://luarocks.org) package manager:

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

### Compiling the custom interpreter

Pallene must be run against a custom-built version of the Lua interpreter.
This custom version of Lua 5.4 doesn't have to be the same one that you will use to run the compiler itself,
or to install the Luarocks packages.

To compile the custom version of Lua, follow the instructions found the vm/doc/readme.html.
For Linux, these are the commands you need to run:

```sh
cd vm
make linux-readline -j
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
$ ./vm/src/lua -l foo
```

It is possible to change compiler optimization level, for the Pallene compiler and C compiler. Here are some examples:

```sh
# execute no optimization (Pallene and C compiler)
$ ./pallenec test.pln -O0

# execute Pallene compiler optimizations and C compiler level 3 optimizations
$ ./pallenec test.pln -O3

# execute no optimizations for Pallene compiler but executes C compiler level 2 optimizations
$ env CFLAGS="-O2" ./pallenec test.pln -O0

# execute all default optimizations (same as -O2)
$ ./pallenec test.pln
```

**Note**: For the C compiler only, the setting set using `CFLAGS` override the setting set by flag `-O`.

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

To run the test suite, run the ./test-project script in this project's root directory.
(Tip: if GNU parallel is installed in your system, running the full test suite will be much faster.)

```sh
$ ./test-project                       # Run all tests
$ ./test-project spec/parser_spec.lua  # Run just one of the test suite files
```

The ./test-project script accepts the same command-line flags as `busted`.
If you are debugging an unhandled exception in a test case, the following ones might help:

Flag                     | Effect
------------------------ | --------------------------------------------------------
./test-project -v        | Verbose output, including the stack trace
./test-project -k        | Run all tests even if some tests are failing
./test-project -o gtest  | Changes the output formatting.<br>This may be clearer if you are using print statements for debugging.

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

> Please run `./benchmarks/generate_lua` to translate all the benchmarks written in Pallene to Lua
> whenever changes are made to the translator.
