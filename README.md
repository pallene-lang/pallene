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

To compile the custom version of Lua, follow the instructions found the [Lua README](https://www.lua.org/manual/5.4/readme.html), also found in the vm/doc/readme.html file.

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
For all the details, please consult the [CONTRIBUTING](CONTRIBUTING.md) file.
