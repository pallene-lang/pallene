#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

typedef struct {
    double x, y, z, vx, vy, vz, mass;
} Body;

#define PI             3.141592653589793
#define SOLAR_MASS     (4.0 * PI * PI)
#define DAYS_PER_YEAR  365.24

#define nbodies 5
static Body bodies[] = {
    { // Sun
         0.0,
         0.0,
         0.0,
         0.0,
         0.0,
         0.0,
         SOLAR_MASS
    },
    { // Jupiter
         4.84143144246472090e+00,
        -1.16032004402742839e+00,
        -1.03622044471123109e-01,
         1.66007664274403694e-03 * DAYS_PER_YEAR,
         7.69901118419740425e-03 * DAYS_PER_YEAR,
        -6.90460016972063023e-05 * DAYS_PER_YEAR,
         9.54791938424326609e-04 * SOLAR_MASS
    },
    { // Saturn
         8.34336671824457987e+00,
         4.12479856412430479e+00,
        -4.03523417114321381e-01,
        -2.76742510726862411e-03 * DAYS_PER_YEAR,
         4.99852801234917238e-03 * DAYS_PER_YEAR,
         2.30417297573763929e-05 * DAYS_PER_YEAR,
         2.85885980666130812e-04 * SOLAR_MASS
    },
    { // Uranus
         1.28943695621391310e+01,
        -1.51111514016986312e+01,
        -2.23307578892655734e-01,
         2.96460137564761618e-03 * DAYS_PER_YEAR,
         2.37847173959480950e-03 * DAYS_PER_YEAR,
        -2.96589568540237556e-05 * DAYS_PER_YEAR,
         4.36624404335156298e-05 * SOLAR_MASS
    },
    { // Neptune
         1.53796971148509165e+01,
        -2.59193146099879641e+01,
         1.79258772950371181e-01,
         2.68067772490389322e-03 * DAYS_PER_YEAR,
         1.62824170038242295e-03 * DAYS_PER_YEAR,
        -9.51592254519715870e-05 * DAYS_PER_YEAR,
         5.15138902046611451e-05 * SOLAR_MASS
    }
};


static
void offset_momentum(Body *bodies, size_t n)
{
    double px = 0.0;
    double py = 0.0;
    double pz = 0.0;
    for (size_t i = 0; i < n; i++) {
      Body *bi = &bodies[i];
      px += (bi->vx * bi->mass);
      py += (bi->vy * bi->mass);
      pz += (bi->vz * bi->mass);
    }
    double solar_mass = bodies[0].mass;
    bodies[0].vx += -px / solar_mass;
    bodies[0].vy += -py / solar_mass;
    bodies[0].vz += -pz / solar_mass;
}

static
void advance(Body *bodies, size_t n, double dt)
{
    for (size_t i = 0; i < n; i++) {
        Body *bi = &bodies[i];
        for (size_t j = i+1; j < n; j++) {
            Body *bj = &bodies[j];
            double dx = bi->x - bj->x;
            double dy = bi->y - bj->y;
            double dz = bi->z - bj->z;
            double dist = sqrt(dx*dx + dy*dy + dz*dz);
            double mag = dt / (dist * dist * dist);

            bi->vx -= dx * bj->mass * mag;
            bi->vy -= dy * bj->mass * mag;
            bi->vz -= dz * bj->mass * mag;

            bj->vx += dx * bi->mass * mag;
            bj->vy += dy * bi->mass * mag;
            bj->vz += dz * bi->mass * mag;
        }
    }
    for (size_t i = 0; i < n; i++) {
        Body *bi = &bodies[i];
        bi->x += dt * bi->vx;
        bi->y += dt * bi->vy;
        bi->z += dt * bi->vz;
    }
}

static
double energy(Body *bodies, size_t n)
{
    double e = 0.0;
    for (size_t i = 0; i < n; i++) {
        Body *bi = &bodies[i];
        double vx = bi->vx;
        double vy = bi->vy;
        double vz = bi->vz;
        e += 0.5 * bi->mass * (vx*vx + vy*vy + vz*vz);
        for (size_t j = i+1; j < n; j++) {
            Body *bj = &bodies[j];
            double dx = bi->x - bj->x;
            double dy = bi->y - bj->y;
            double dz = bi->z - bj->z;
            double distance = sqrt(dx*dx + dy*dy + dz*dz);
            e -= (bi->mass * bj->mass) / distance;
        }
    }
    return e;
}

int main(int argc, char **argv)
{
    size_t N = 1000; // or 50000000
    if (argc > 1) {
        int nread = sscanf(argv[1], "%zu", &N);
        if (nread != 1) return 1;
    }

    size_t nrep = 1;
    if (argc > 2) {
        int nread = sscanf(argv[2], "%zu", &nrep);
        if (nread != 1) return 1;
    }

    //

    offset_momentum(bodies, nbodies);
    printf("%0.9f\n", energy(bodies, nbodies));
    for (size_t rep = 0; rep < nrep; rep++) {
        for (size_t i = 0; i < N; i++) {
            advance(bodies, nbodies, 0.01);
        }
    }
    printf("%0.9f\n", energy(bodies, nbodies));

    return 0;
}

