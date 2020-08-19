.PHONY: notarget

notarget:
	@echo "This makefile must receive a target"
	@echo "example: make benchmarks/matmul/pallene.so"

%.so: %.pln
	./pallenec $<

%.so: %.c
	./pallenec --compile-c $<

%/lua.lua: %/pallene.pln
	./pallenec --emit-lua $<
	mv $(basename $<).lua $@
