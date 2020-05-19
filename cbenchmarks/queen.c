#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

int isplaceok(int *a, int n, int c)
{
    for (int i = 0; i < n; i++) {
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

void printsolution(int N, int *a)
{
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
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

void addqueen(int N, int *a, int n)
{
    if (n >= N) {
        printsolution(N, a);
    } else {
        for (int c = 0; c < N; c++) {
            if (isplaceok(a, n, c)) {
                a[n] = c;
                addqueen(N, a, n+1);
            }
        }
    }
}

void nqueens(int N)
{
    int *a = malloc(N * sizeof(*a));
    addqueen(N, a, 0);
    free(a);
}

int main(int argc, char **argv)
{
    int N = 13;
    if (argc > 1) {
        int nread = sscanf(argv[1], "%d", &N);
        if (nread != 1) return 1;
    }

    //

    nqueens(13);
    return 0;
}
