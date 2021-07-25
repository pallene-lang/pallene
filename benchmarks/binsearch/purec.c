#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// Use 1-based arrays!
size_t binsearch(int64_t *t, size_t N, int64_t x)
{
    size_t lo = 1;
    size_t hi = N;

    size_t steps = 0;

    while (lo < hi) {
        size_t mid = lo + (hi - lo)/2;
        steps++;
        int64_t tmid = t[mid];

        if (x == tmid) {
            return steps;
        } else if (x < tmid) {
            hi = mid - 1;
        } else {
            lo = mid + 1;
        }
    }

    return steps;
}

size_t test(int64_t *t, size_t N, size_t nrep)
{
    size_t out = 0;
    for (size_t i = 1; i <= nrep; i++) {
        if (binsearch(t, N, i) != 22) {
            out++;
        }
    }
    return out;
}

int main(int argc, char **argv)
{
    size_t N = 1000000;
    if (argc > 1) {
        int nread = sscanf(argv[1], "%zu", &N);
        if (nread != 1) return 1;
    }

    size_t nrep = N;
    if (argc > 2) {
        int nread = sscanf(argv[2], "%zu", &nrep);
        if (nread != 1) return 1;
    }

    //

    int64_t *xs = malloc((1+N)*sizeof(int64_t));
    for (size_t i = 1; i <= N; i++) {
        xs[i] = i;
    }

    size_t out = test(xs, N, nrep);
    printf("%lu\n", out);
}
