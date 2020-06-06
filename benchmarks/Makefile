.PHONY: notarget

notarget:
	@echo "This makefile must receive a target"
	@echo "example: make benchmarks/matmul/pallene.so"

%.so: %.pln
	./pallenec $<

%.so: %.c
	./pallenec --compile-c $<
