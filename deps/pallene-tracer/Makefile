# Copyright (c) 2024, The Pallene Developers
# Pallene Tracer is licensed under the MIT license.
# Please refer to the LICENSE and AUTHORS files for details
# SPDX-License-Identifier: MIT

# Where to install our things
PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
INCDIR = $(PREFIX)/include

# Where to find Lua libraries
LUA_PREFIX = /usr
LUA_BINDIR = $(LUA_PREFIX)/bin
LUA_INCDIR = $(LUA_PREFIX)/include
LUA_LIBDIR = $(LUA_PREFIX)/lib

# How to install files
INSTALL= install -p
INSTALL_EXEC= $(INSTALL) -m 0755
INSTALL_DATA= $(INSTALL) -m 0644

# C compilation flags
CFLAGS   = -DPT_DEBUG -g -std=c99 -pedantic -Wall -Wextra -Wformat-security
# Explicitly mention which Lua headers to capture
CPPFLAGS = -I$(LUA_INCDIR) -I.
LIBFLAG  = -fPIC -shared

# The -Wl,-E tells the linker to not throw away unused Lua API symbols.
# We need them for Lua modules that are dynamically linked via require
PTLUA_LDFLAGS = -L$(LUA_LIBDIR) -Wl,-E
PTLUA_LDLIBS  = -llua -lm

# ===================
# Compilation targets
# ===================

.PHONY: library examples tests all install uninstall clean

library: \
	pt-lua

examples: library \
	examples/fibonacci/fibonacci.so

tests: library \
        spec/tracebacks/anon_lua/module.so \
        spec/tracebacks/depth_recursion/module.so \
        spec/tracebacks/dispatch/module.so \
        spec/tracebacks/ellipsis/module.so \
        spec/tracebacks/multimod/module_a.so \
        spec/tracebacks/multimod/module_b.so \
        spec/tracebacks/singular/module.so

all: library examples tests

install: library
	$(INSTALL_EXEC) pt-lua $(BINDIR)
	$(INSTALL_DATA) ptracer.h $(INCDIR)

uninstall:
	rm -rf $(INCDIR)/ptracer.h
	rm -rf $(BINDIR)/pt-run

clean:
	rm -rf pt-lua examples/*/*.so spec/tracebacks/*/*.so

%.so: %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) $(LIBFLAG) $< -o $@

pt-lua: pt-lua.c ptracer.h
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) $(PTLUA_LDFLAGS) $< -o $@ $(PTLUA_LDLIBS)

examples/fibonacci/fibonacci.so:           examples/fibonacci/fibonacci.c           ptracer.h
spec/tracebacks/anon_lua/module.so:        spec/tracebacks/anon_lua/module.c        ptracer.h
spec/tracebacks/depth_recursion/module.so: spec/tracebacks/depth_recursion/module.c ptracer.h
spec/tracebacks/dispatch/module.so:        spec/tracebacks/dispatch/module.c        ptracer.h
spec/tracebacks/ellipsis/module.so:        spec/tracebacks/ellipsis/module.c        ptracer.h
spec/tracebacks/multimod/module_a.so:      spec/tracebacks/multimod/module_a.c      ptracer.h
spec/tracebacks/multimod/module_b.so:      spec/tracebacks/multimod/module_b.c      ptracer.h
spec/tracebacks/singular/module.so:        spec/tracebacks/singular/module.c        ptracer.h
