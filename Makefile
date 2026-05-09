all:
	cd ./deps/lua-internals  && $(MAKE) guess
	cd ./deps/pallene-tracer && $(MAKE)   \
		LUA_PREFIX="../lua-internals"     \
		LUA_BINDIR="../lua-internals/src" \
		LUA_INCDIR="../lua-internals/src" \
		LUA_LIBDIR="../lua-internals/src"
	cd ./src/lpeg            && $(MAKE) LUADIR="../../deps/lua-internals/src"

clean:
	cd ./deps/lua-internals  && $(MAKE) clean
	cd ./deps/pallene-tracer && $(MAKE) clean
	cd ./src/lpeg            && $(MAKE) clean

