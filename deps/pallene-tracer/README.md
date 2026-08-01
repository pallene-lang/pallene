<h1 align="center">The Pallene Tracer</h1>

Pallene Tracer allows Lua libraries written in C to have proper function tracebacks, without changing a single code in Lua!

Pallene Tracer was created to address the need for function tracebacks in [Pallene](https://github.com/pallene-lang/pallene), an Ahead-of-Time compiled sister language to Lua. Pallene is intermediately compiled to C, hence protocols and mechanism used can be ported to broader Lua C libraries.

> **Note:** Pallene Tracer is independent of Pallene but not vice versa.

## Installing Pallene Tracer

### Prerequisites

You need to have **_atleast Lua 5.4_** installed in your system at any location.

### Building

To build against `/usr` Lua prefix (system Lua), just simply run:
```
make
```

To build against local Lua with `/usr/local` prefix (or any prefix):
```
make LUA_PREFIX=/usr/local
```

> **Note:** Default `LUA_PREFIX` is `/usr`.

The linker supplied with Apple's Xcode command line developer tools does not use the same flag conventions as the GNU linker, gold, LLVM lld, etc. **On macos**, you may have to manually specify the `-export_dynamic` linker flag:

```
make EXPFLAG=-export_dynamic LUA_PREFIX=<preferred_prefix>
```

Pallene Tracer sometime fails to build if Lua is built with address sanitizer (ASan) enabled. To get around the issue use: 
```
make LDFLAGS=-lasan LUA_PREFIX=<preferred_prefix>
```

### Installing

To install Pallene Tracer to `/usr/local`, simply run:
```
sudo make install
```

Pallene Tracer supplies a custom Lua frontend `pt-lua` and `ptracer.h` header (including source).

### Runnning tests

If your lua prefix is `/usr`, simply run:
```
./run-tests
```

If you are using a local lua prefix (not `/usr`), you will need to build the tests separately before running the test script:
```
make LUA_PREFIX=<preferred_prefix> tests
./run-tests
```

### How to use Pallene Tracer

The developers manual on how Pallene Tracer works and used can be found in [docs](https://github.com/pallene-lang/pallene-tracer/blob/main/docs/MANUAL.md). Also feel free to look at the `examples` directory for further intuition.
