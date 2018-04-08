local sieve = require(arg[1])

local ps
for i = 1, 1000 do
    ps = sieve.sieve(10000)
end
print(#ps)
