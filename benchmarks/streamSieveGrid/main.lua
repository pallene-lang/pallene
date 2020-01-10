--
-- This benchmark runs a naive prime sieve using lazy streams. Taken from the
-- Typed Racket benchmarks:
--  * https://github.com/nuprl/gradual-typing-performance/tree/master/benchmarks/sieve
--  * https://github.com/bennn/gtp-benchmarks/tree/master/benchmarks/sieve
--

local modname = arg[1]
local luaname = arg[2] or "injectLua"
local INJECT  = tonumber(arg[3]) or 0
local N       = tonumber(arg[4]) or 2000 -- or 5500

local prefix = string.match(modname, "^(.*)%.")

local luaVersion = require(prefix .. "." .. luaname)
local plnVersion = require(prefix .. ".injectPln")

for i, submodule in ipairs({ "Stream", "Main" }) do
    local mask = 1 << (i-1)
    local injector = "inject"..submodule

    if (0 == INJECT & mask) then
        plnVersion[injector](luaVersion)
    else
        luaVersion[injector](plnVersion)
    end
end

print(string.format("primes(%d) = %d", N, luaVersion.get_prime(N)))
