#include <stdio.h>
#include <stdlib.h>

typedef struct {
    double x;
    double y;
} Point;

Point *new_point(double x, double y)
{
    Point *p = malloc(sizeof(double));
    p->x = x;
    p->y = y;
    return p;
}

Point *centroid(Point **points, size_t N, size_t nrep)
{
    double x = 0.0;
    double y = 0.0;
    for (size_t rep = 0; rep < nrep; rep++) {
        x = 0.0;
        y = 0.0;
        for (size_t i = 0; i < N; i++) {
            Point *p = points[i];
            x += p->x;
            y += p->y;
        }
    }
    return new_point(x/N, y/N);
}

int main()
{
    size_t N = 10000;
    Point **points = malloc(N * sizeof(Point*));
    for (size_t i = 0; i < N; i++) {
        double d = (i+1) * 3.1415;
        points[i] = new_point(d, d);
    }

    Point *p = centroid(points, N, 50000);
    printf("%lf %lf\n", p->x, p->y);
}

