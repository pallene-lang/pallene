local sieve = require(arg[1])
local N     = tonumber(arg[2]) or 100000
local nrep  = tonumber(arg[3]) or 1000

local ps
for _ = 1, nrep do
    ps = sieve.sieve(N)
end
print(#ps)
