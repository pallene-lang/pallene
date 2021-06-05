CFLAGS=-std=c11 -Wall -Wextra -pedantic -O2 -lm

EXES:=binsearch centroid conway matmul sieve queen nbody

all: $(EXES)

binsearch: binsearch.c
centroid: centroid.c
conway: conway.c
matmul: matmul.c
sieve: sieve.c
queen: queen.c
nbody: nbody.c

.PHONY: clean
clean:
	rm -f -- $(EXES)
