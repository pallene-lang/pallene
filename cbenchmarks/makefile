CFLAGS=-std=c11 -Wall -pedantic -O2

OBJS:=binsearch centroid conway matmul sieve queen

all: $(OBJS)

binsearch: binsearch.c
centroid: centroid.c
conway: conway.c
matmul: matmul.c
sieve: sieve.c
queen: queen.c

.PHONY: clean
clean:
	rm -f -- $(OBJS)
