local sieve = require(arg[1])

local ps
for i = 1, 10000 do
    ps = sieve.sieve(10000)
end
print(#ps)
