#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// Time with char    *isprime: 0.40 s
// Time with int64_t *isprime: 0.65 s

void sieve(size_t N, int64_t **primes_out, size_t *nprimes_out)
{
    char *is_prime = calloc(1+N, sizeof(char));
    is_prime[1] = 0;
    for (size_t n = 2; n <= N; n++) {
        is_prime[n] = 1;
    }

    size_t nprimes_capacity = 1;
    size_t nprimes = 0;
    int64_t *primes = malloc(nprimes_capacity * sizeof(int64_t));

    for (size_t n = 1; n <= N; n++) {
        if (is_prime[n]) {
            if (nprimes >= nprimes_capacity) {
                nprimes_capacity *= 2;
                primes = realloc(primes, nprimes_capacity * sizeof(int64_t));
                if (!primes) { exit(1); }
            }
            primes[nprimes++] = n;
            for (size_t m = n+n; m <= N; m += n) {
                is_prime[m] = 0;
            }
        }
    }

    *primes_out = primes;
    *nprimes_out = nprimes;
}

int main()
{
    int64_t *primes = NULL;
    size_t nprimes;
    for (int i = 0; i < 1000; i++) {
        free(primes);
        sieve(100000, &primes, &nprimes);
    }
    printf("%lu\n", nprimes);
}

