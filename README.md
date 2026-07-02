# Pallene

[![Actions Status](https://github.com/pallene-lang/pallene/workflows/Github%20Actions%20CI/badge.svg)](https://github.com/pallene-lang/pallene/actions)

Pallene is a statically typed and ahead-of-time compiled sister language to
[Lua](https://www.lua.org), with a focus on performance.
It is intended for writing performance-sensitive code that interacts with
Lua, a space that is currently filled by C modules and by LuaJIT. Compared to
C, Pallene should offer better support for interacting with Lua data types,
bypassing the unfriendly syntax and performance overhead of the Lua-C API.
Compared to LuaJIT, Pallene aims to offer more predictable run-time performance.

## Building and Installing Pallene

Before you are able to build and install Pallene, you'll need to run the
configure script.

You can also, optionally, modify the installation location via the configure
script. See `./configure --help` for details. The default location is
`/usr/local`.

```sh
./configure
make
```

To install Pallene and all of its dependencies:

```sh
sudo make install
```

## Using Pallene

Installing Pallene will put two binaries&mdash;`pallenec` and `pallene-lua`&mdash;on your `PATH`.
`pallenec` is for compiling Pallene programs and `pallene-lua` is for running Lua programs
that load Pallene modules.

To compile a `foo.pln` file to a `foo.so` module:

```sh
pallenec foo.pln
```

The resulting `foo.so` can be loaded via the usual `require` mechanism:

```sh
pallene-lua -l foo
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

For more compiler options, see `pallenec --help`.

## Contributing

If you want to contribute to Pallene, it is helpful to know how to run our test suite
and how to configure your text editor to preserve our style standard.
For all the details, please consult the [CONTRIBUTING](CONTRIBUTING.md) file.

Pallene has a **Strict No LLM / No AI Policy**

* No LLMs for issues.
* No LLMs for patches / pull requests.
* No LLMs for comments on the bug tracker, including translation.
* English is encouraged, but not required. You are welcome to post in your native language and rely on others to have their own translation tools of choice to interpret your words.
