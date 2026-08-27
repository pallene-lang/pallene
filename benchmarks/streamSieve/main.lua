--
-- This benchmark runs a naive prime sieve using lazy streams. Taken from the
-- Typed Racket benchmarks:
--  * https://github.com/nuprl/gradual-typing-performance/tree/master/benchmarks/sieve
--  * https://github.com/bennn/gtp-benchmarks/tree/master/benchmarks/sieve
--

local sieve = require(arg[1])
local N     = tonumber(arg[2]) or 2000 -- or 5500

print(string.format("primes(%d) = %d", N, sieve.get_prime(N)))
