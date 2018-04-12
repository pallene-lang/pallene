CPPFLAGS:=-I./lua/src
CFLAGS:=--std=c99 -g -Wall -O2 -fPIC -shared

.PHONY: all lua

all: lua runtime/tcore.o

lua:
	cd lua/src; make linux-readline

runtime/tcore.o: runtime/tcore.c runtime/tcore.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
