local nbody = require(arg[1])
local N   = tonumber(arg[2]) or 1000 -- or 50000000
local REP = tonumber(arg[3]) or 1

-- N-body benchmark from benchmarks game
-- https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/nbody.html
--
-- Original code by Mike Pall and Geoff Leyland, with modifications by Hugo
-- Gualandi for correctness, clarity, and compatibility with Pallene.
--   * Fix implementation of advance() to use two outer loops.
--   * Use #xs instead of passing "n" as a parameter to all the functions
--   * Use math.sqrt instead of caching sqrt in a local variable
--   * Use 0.0 instead of 0 where appropriate.
--   * Don't use multiple assignments.
--
-- Expected output (N = 1000):
--   -0.169075164
--   -0.169087605
--
-- Expected output (N = 50000000):
--   -0.169075164
--   -0.169059907

local PI = 3.141592653589793
local SOLAR_MASS = 4 * PI * PI
local DAYS_PER_YEAR = 365.24
local bodies = {
  nbody.new_body( -- Sun
     0.0,
     0.0,
     0.0,
     0.0,
     0.0,
     0.0,
     SOLAR_MASS),
  nbody.new_body( -- Jupiter
     4.84143144246472090e+00,
    -1.16032004402742839e+00,
    -1.03622044471123109e-01,
     1.66007664274403694e-03 * DAYS_PER_YEAR,
     7.69901118419740425e-03 * DAYS_PER_YEAR,
    -6.90460016972063023e-05 * DAYS_PER_YEAR,
     9.54791938424326609e-04 * SOLAR_MASS ),
  nbody.new_body( -- Saturn
     8.34336671824457987e+00,
     4.12479856412430479e+00,
    -4.03523417114321381e-01,
    -2.76742510726862411e-03 * DAYS_PER_YEAR,
     4.99852801234917238e-03 * DAYS_PER_YEAR,
     2.30417297573763929e-05 * DAYS_PER_YEAR,
     2.85885980666130812e-04 * SOLAR_MASS ),
  nbody.new_body( -- Uranus
     1.28943695621391310e+01,
    -1.51111514016986312e+01,
    -2.23307578892655734e-01,
     2.96460137564761618e-03 * DAYS_PER_YEAR,
     2.37847173959480950e-03 * DAYS_PER_YEAR,
    -2.96589568540237556e-05 * DAYS_PER_YEAR,
     4.36624404335156298e-05 * SOLAR_MASS ),
  nbody.new_body( -- Neptune
     1.53796971148509165e+01,
    -2.59193146099879641e+01,
     1.79258772950371181e-01,
     2.68067772490389322e-03 * DAYS_PER_YEAR,
     1.62824170038242295e-03 * DAYS_PER_YEAR,
    -9.51592254519715870e-05 * DAYS_PER_YEAR,
     5.15138902046611451e-05 * SOLAR_MASS ),
}

nbody.offset_momentum(bodies)
print(string.format("%0.9f", nbody.energy(bodies)))
for _ = 1, REP do
    nbody.advance_multiple_steps(N, bodies, 0.01)
end
print(string.format("%0.9f", nbody.energy(bodies)))
