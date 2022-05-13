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

Pallene requires a special version of Lua, which you will likely need to build from source.
You will also likely need to build and install Luarocks from source.

### Install the special Lua

First, you need to install a Pallene-compatible version of Lua.
This version of Lua is patched to expose some extra C APIs that Pallene needs.
You can download it from [our other repository](https://www.github.com/pallene-lang/lua-internals).
Make sure to get version 5.4.4, because the minor patch number is important.

```sh
wget https://www.github.com/pallene-lang/lua-internals/relelases/tag/v5.4.4
tar xf lua-internals-5.4.4.tar.gz
cd lua-internals-5.4.4
make linux-readline -j4
sudo make install
```

To check if you have installed the right version of Lua, run `lua -v`.
It needs to say `Lua 5.x.x with core API`.
If the message doesn't have the "with core API", that means you're using vanilla Lua.

### Install Luarocks from source

You will probably also need to install Luarocks from source.
We can't use the Luarocks from the package manager because that way it won't use the custom version of Lua we just installed.

For more information on how to install Luarocks, please see the [Luarocks wiki](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Unix).
In the configure step, use the `--with-lua` flag to point to where we installed the custom Lua.

```sh
wget https://luarocks.org/releases/luarocks-3.9.0.tar.gz
tar xf luarocks-3.9.0.tar.gz
cd luarocks-3.9.0
./configure --with-lua=/usr/local
make
sudo make install
```

By default, Luarocks installs packages to the root directory, which requires sudo.
If you are like me, you might prefer to intall to your home directory by default.

```sh
# Run this one time
luarocks config local_by_default true
```

Remember that in order for the local rocks tree to work, you must to set some environment variables

```sh
# Add this line to your ~/.bashrc
eval "$(luarocks path)"
```

### Build and install Pallene

Finally, we can use Luarocks to build and install the Pallene compiler.
This will also download and install the necessary Lua dependencies.

```
luarocks make pallene-dev-1.rockspec
```

## Using Pallene

To compile a `foo.pln` file to a `foo.so` module call `pallenec` as follows.

```sh
$ pallenec foo.pln
```

The resulting `foo.so` can be used by Lua via the usual `require` mechanism.

```sh
$ lua -l foo
```

It is possible to change the compiler optimization level, for the Pallene compiler and C compiler.
Here are some examples:

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

**Note**: For the C compiler only, the setting set using `CFLAGS` overrides the setting set by flag `-O`.

For more compiler options, see `./pallenec --help`

## Developing Pallene

If you want to develop Pallene, it is helpful to know how to configure your
editor to preserve our style standards, and to know how to run the test suite.
For all the details, please consult the [CONTRIBUTING](CONTRIBUTING.md) file.
