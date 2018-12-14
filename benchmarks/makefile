.PHONY: default

default:
	@echo "This makefile must receive a target"
	@echo "example: make benchmarks/matmul/pallene.so"

%.so: %.pallene
	./pallenec $<

%.so: %.c
	./pallenec --compile-c $<
