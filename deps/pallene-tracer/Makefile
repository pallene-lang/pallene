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
ifeq ($(shell uname -s),Darwin)
LIBFLAG  = -fPIC -shared -undefined dynamic_lookup
else
LIBFLAG  = -fPIC -shared
endif
SO_LDFLAGS = -L$(LUA_LIBDIR) -llua

# Keep unused Lua API symbols for modules loaded via require.
# GNU ld wants -Wl,-E; Apple ld wants -Wl,-export_dynamic.
# -rdynamic is the portable compiler flag that maps to the right one.
PTLUA_LDFLAGS = -L$(LUA_LIBDIR) -rdynamic
PTLUA_LDLIBS  = -llua -lm

# ===================
# Compilation targets
# ===================

.PHONY: library examples tests all install uninstall clean

library: \
	pallene-lua

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
	$(INSTALL_EXEC) pallene-lua $(BINDIR)
	$(INSTALL_DATA) ptracer.h $(INCDIR)

uninstall:
	rm -rf $(INCDIR)/ptracer.h
	rm -rf $(BINDIR)/pallene-lua

clean:
	rm -rf pt-lua.c
	rm -rf pallene-lua examples/*/*.so spec/tracebacks/*/*.so
	rm -rf pallene-lua.dSYM spec/tracebacks/*/*.dSYM examples/*/*.dSYM

%.so: %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) $(SO_LDFLAGS) $(LIBFLAG) $< -o $@

pallene-lua: lua.c ptracer.h
	cp lua.c pt-lua.c
	patch pt-lua.c < replace-traceback.patch
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) $(PTLUA_LDFLAGS) -DLUA_PROGNAME=\"pallene-lua\" pt-lua.c -o $@ $(PTLUA_LDLIBS)

examples/fibonacci/fibonacci.so:           examples/fibonacci/fibonacci.c           ptracer.h
spec/tracebacks/anon_lua/module.so:        spec/tracebacks/anon_lua/module.c        ptracer.h
spec/tracebacks/depth_recursion/module.so: spec/tracebacks/depth_recursion/module.c ptracer.h
spec/tracebacks/dispatch/module.so:        spec/tracebacks/dispatch/module.c        ptracer.h
spec/tracebacks/ellipsis/module.so:        spec/tracebacks/ellipsis/module.c        ptracer.h
spec/tracebacks/multimod/module_a.so:      spec/tracebacks/multimod/module_a.c      ptracer.h
spec/tracebacks/multimod/module_b.so:      spec/tracebacks/multimod/module_b.c      ptracer.h
spec/tracebacks/singular/module.so:        spec/tracebacks/singular/module.c        ptracer.h
