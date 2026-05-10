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


LUA_VERSION = 5.4
INSTALL_PREFIX = /usr/local

RM = rm -f 
RM_DIR = rm -rf

install:
	cd ./deps/lua-internals  && $(MAKE) install INSTALL_TOP=$(INSTALL_PREFIX)
	cd ./deps/pallene-tracer && $(MAKE) install PREFIX=$(INSTALL_PREFIX)

	cp ./src/argparse.lua $(INSTALL_PREFIX)/share/lua/$(LUA_VERSION)
	cp ./src/lpeg/re.lua  $(INSTALL_PREFIX)/share/lua/$(LUA_VERSION)
	cp ./src/lpeg/lpeg.so $(INSTALL_PREFIX)/lib/lua/$(LUA_VERSION)

	cp -r ./src/pallene      $(INSTALL_PREFIX)/share/lua/$(LUA_VERSION)
	cp    ./src/bin/pallenec $(INSTALL_PREFIX)/bin

uninstall:
	cd ./deps/lua-internals  && $(MAKE) uninstall INSTALL_TOP=$(INSTALL_PREFIX)
	cd ./deps/pallene-tracer && $(MAKE) uninstall PREFIX=$(INSTALL_PREFIX)

	$(RM) $(INSTALL_PREFIX)/share/lua/$(LUA_VERSION)/argparse.lua
	$(RM) $(INSTALL_PREFIX)/share/lua/$(LUA_VERSION)/re.lua
	$(RM) $(INSTALL_PREFIX)/lib/lua/$(LUA_VERSION)/lpeg.so

	$(RM_DIR) $(INSTALL_PREFIX)/share/lua/$(LUA_VERSION)/pallene
	$(RM) $(INSTALL_PREFIX)/bin/pallenec

