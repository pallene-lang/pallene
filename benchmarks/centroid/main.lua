local point = require(arg[1])
local N     = tonumber(arg[2]) or 10000
local nrep  = tonumber(arg[3]) or 50000

local arr = {}
for i = 1, N do
    local d = i * 3.1415
    arr[i] = point.new(d, d)
end

local r = point.centroid(arr, nrep)
print(r[1], r[2])
