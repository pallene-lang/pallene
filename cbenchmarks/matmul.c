#include <math.h>
#include <stdio.h>
#include <stdlib.h>

// Multiplies a NI x NK matrix by a NK x NJ matrix
double **matmul(double **A, double**B, size_t NI, size_t NK, size_t NJ)
{
    double **C = calloc(NI, sizeof(double*));
    for (size_t i = 0; i < NI; i++) {
        C[i] = calloc(NJ, sizeof(double));
        for (size_t j = 0; j < NJ; j++) {
            C[i][j] = 0.0;
        }
    }

    for (size_t k = 0; k < NK; k++) {
        double *Bk = B[k];
        for (size_t i = 0; i < NI; i++) {
            double Aik = A[i][k];
            double* Ci = C[i];
            for (size_t j = 0; j < NK; j++) {
                Ci[j] += Aik * Bk[j];
            }
        }
    }

    return C;
}

static
int max(double a, double b) { return (a >= b ? a : b); }

int main(int argc, char **argv)
{
    size_t N = 800;
    if (argc > 1) {
        int nread = sscanf(argv[1], "%zu", &N);
        if (nread != 1) return 1;
    }

    size_t nrep = max(1.0, 2.0 * pow(800/N, 3));
    if (argc > 2) {
        int nread = sscanf(argv[2], "%zu", &nrep);
        if (nread != 1) return 1;
    }

    //

    double **A = calloc(N, sizeof(double*));
    for (size_t i = 0; i < N; i++) {
        A[i] = calloc(N, sizeof(double));
        for (size_t j = 0; j < N; j++) {
            A[i][j] = (i + j + 2) * 3.1415;
        }
    }

    double **C = NULL;
    for (int i = 0; i < nrep; i++) {
        free(C);
        C = matmul(A, A, N, N, N);
    }

    printf("%lu\n", N);
    printf("%lf\n", C[0][0]);
}
