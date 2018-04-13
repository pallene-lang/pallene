CPPFLAGS:=-I./lua/src
CFLAGS:=--std=c99 -g -Wall -O2 -fPIC

.PHONY: default clean linux-readline lua-linux-readline macos lua-macos

default:
	@echo "Please do 'make PLATFORM' where PLATFORM is one of these:"
	@echo "  linux-readline macos"

clean:
	cd lua/src && $(MAKE) clean
	rm -f ./runtime/*.o ./runtime/*.a


linux-readline: runtime/tcore.o lua-linux-readline
macos:          runtime/tcore.o lua-macos

lua-linux-readline:
	cd lua/src && $(MAKE) linux-readline

lua-macos:
	cd lua/src && $(MAKE) macos

runtime/tcore.o: runtime/tcore.c runtime/tcore.h
