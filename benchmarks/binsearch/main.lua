local bs = require(arg[1])
local N    = tonumber(arg[2]) or 1000000
local nrep = tonumber(arg[3]) or N

local t = {}
for x = 1, N do
    t[x] = math.random(N)
end

local r = bs.test(t, nrep)
print(r)
