CFLAGS=-std=c11 -Wall -pedantic -O2 -lm

EXES:=binsearch centroid conway matmul sieve queen

all: $(EXES)

binsearch: binsearch.c
centroid: centroid.c
conway: conway.c
matmul: matmul.c
sieve: sieve.c
queen: queen.c

.PHONY: clean
clean:
	rm -f -- $(EXES)
