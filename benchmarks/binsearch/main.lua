local bs = require(arg[1])

local t = {}
for x = 1, 1000000 do
    t[x] = x
end

local r = bs.test(t)
print(r)
