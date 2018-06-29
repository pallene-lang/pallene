#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

int isplaceok(size_t *a, size_t n, size_t c)
{
    for (size_t i = 0; i < n; i++) {
        int d = a[i];
        if (
            (d == c) ||
            (d - i == c - n) ||
            (d + i == c + n)
        ){
            return 0;
        }
    }
    return 1;
}

void printsolution(size_t N, size_t *a)
{
    for (size_t i = 0; i < N; i++) {
        for (size_t j = 0; j < N; j++) {
            if (a[i] == j) {
                putchar('X');
            } else {
                putchar('-');
            }
            putchar(' ');
        }
        putchar('\n');
    }
    putchar('\n');
}

void addqueen(size_t N, size_t *a, size_t n)
{
    if (n >= N) {
        printsolution(N, a);
    } else {
        for (size_t c = 0; c < N; c++) {
            if (isplaceok(a, n, c)) {
                a[n] = c;
                addqueen(N, a, n+1);
            }
        }
    }
}

void nqueens(size_t N)
{
    size_t *a = malloc(N * sizeof(size_t));
    addqueen(N, a, 0);
    free(a);
}

int main()
{
    nqueens(12);
    return 0;
}
