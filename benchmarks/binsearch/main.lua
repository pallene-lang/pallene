local bs = require(arg[1])
local N  = tonumber(arg[2]) or 1000000

local t = {}
for x = 1, N do
    t[x] = x
end

local r = bs.test(t)
print(r)
