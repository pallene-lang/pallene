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

### Installing the Prerequisites

The first thing we will need is a C compiler (e.g. `gcc` or `clang`).
Ubuntu users can run the following command to install it:
```sh
sudo apt install build-essential
```

Next, you will need Lua 5.4.4 (exactly!).
Differently from most Lua tools, Pallene requires a particular sub-version of Lua.
This is because we interface with "forbidden" low-level Lua APIs,
which can change even on a minor bugfix patch.
If your Linux distro has the very latest version of Lua,
you might be able to use the version from the package repositories.
But if your distro has an older version of Lua (e.g. Ubuntu or Debian) then you will probably want to [install Lua from source](https://www.lua.org/ftp/).

Finally, you will need to install Luarocks.
If in the previous step you had to install Lua from source,
then you will also have to [install Luarocks from source](https://luarocks.org/#quick-start).
Make sure that it is set up to use the Lua 5.4.4.
If it is not, you can change that using the Luarocks configure script.
Run its `./configure --help` for more details.

### Code generation

If you are cloning Pallene from Git,
then the first step of the installation is to generate some automatically-generated files.

```sh
./generate-pallenelib.lua
```

### Build using Luarocks

You can now use the the usual Luarocks commands to install Pallene.
This will also install the Lua dependencies (e.g argparse), if necessary.

```sh
$ luarocks make --local pallene-dev-1.rockspec
```

If you get an error complaining that _corelib.c is missing,
that means you forgot the code generation step before (the previous section).

If you use the --local flag when installing packages from Luarocks,
you may also need to configure the appropriate environment variables on your terminal configuration file.
If you are using bash you can do the following, as stated in `luarocks --help path`:
```sh
$ echo 'eval `luarocks path`' >> ~/.bashrc
```
For further information, please consult the [Luarocks documentation](https://github.com/luarocks/luarocks/wiki/path).

## Using Pallene

To compile a `foo.pln` file to a `foo.so` module, call `pallenec` as follows.

```sh
$ pallenec foo.pln
```

Your Pallene module can now be used via "require":


```sh
$ lua -l foo
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

## Contributing

If you want to contribute to the Pallene compiler itself,
it will be helpful to know how to run the test suite and how to configure your text editor.
For all the details, please consult the [CONTRIBUTING](CONTRIBUTING.md) file.
