# Pallene
[![Actions Status](https://github.com/pallene-lang/pallene/workflows/Github%20Actions%20CI/badge.svg)](https://github.com/pallene-lang/pallene/actions)

Pallene is a statically typed and ahead-of-time compiled sister language to
[Lua](https://www.lua.org), with a focus on performance.
It is intended for writing performance sensitive code that interacts with
Lua, a space that is currently filled by C modules and by LuaJIT. Compared to
C, Pallene should offer better support for interacting with Lua data types,
bypassing the unfriendly syntax and performance overhead of the Lua-C API.
Compared to LuaJIT, Pallene aims to offer more predictable run-time performance.

## Installing Pallene

Pallene requires a special version of Lua, which you will need to build from source.
You will also need to install the Luarocks package manager.

### Install the special Lua

You must download and compile the Lua from [our other repository](https://www.github.com/pallene-lang/lua-internals).
This version of Lua is patched to expose some additional C APIs that Pallene needs.

```sh
git clone https://www.github.com/pallene-lang/lua-internals/
cd lua-internals
make guess -j4
sudo make install
```

If you are on Linux and would like the up arrow to work in the Lua REPL,
then run `make linux-readline` instead of `make guess`.
After Lua is installed, run `lua -v` to check if you have the right version.
It needs to say `Lua 5.x.x with core API`.
If it doesn't have the "with core API",
that means you're using the default Lua instead of the special Lua.

### Install Luarocks

The next step is to get the Luarocks package manager.
Because we built our Lua from source, we must also [build Luarocks from source](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Unix).
You can't download Luarocks from your Linux distro, because that would use the wrong version of Lua.
To build Luarocks, unpack the sources and run `configure`, `make`, and `make install`.
In the configure step, use `--with-lua` to point to our special Lua.

```sh
wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz
tar xf luarocks-3.11.1.tar.gz
cd luarocks-3.11.1
./configure --with-lua=/usr/local
make
sudo make install
```

By default, Luarocks installs packages into /usr/local, which requires sudo.
If you prefer to install to your home directory by default, enable the `local_by_default` setting.

```sh
luarocks config local_by_default true
```

Remember that in order for the local rocks tree to work, you must to set the PATH and LUA_PATH environment variables.

```sh
# Add this line to your ~/.bashrc
eval "$(luarocks path)"
```

### Install Pallene

Finally, we can use Luarocks to build and install the Pallene compiler.
This will also download and install the necessary Lua libraries.

```sh
luarocks make pallene-dev-1.rockspec
```

## Using Pallene

To compile a `foo.pln` file to a `foo.so` module, call `pallenec` as follows.

```sh
pallenec foo.pln
```

The resulting `foo.so` can be loaded via the usual `require` mechanism.

```sh
lua -l foo
```

It is possible to change the compiler optimization level, for the Pallene compiler and C compiler.
Here are some examples:

```sh
# disable Pallene optimization passes
pallenec test.pln -O0

# disable C compiler optimization
export CFLAGS='-O0'
pallenec test.pln
```

For more compiler options, see `./pallenec --help`

## Developing Pallene

If you want to contribute to Pallene, it is helpful to know how to run our test suite
and how to configure your text editor to preserve our style standard.
For all the details, please consult the [CONTRIBUTING](CONTRIBUTING.md) file.
