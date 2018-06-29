local point = require(arg[1])

local arr = {}
for i = 1, 10000 do
    local d = i * 3.1415
    arr[i] = point.new(d, d)
end

local r = point.centroid(arr, 10000)
print(r[1], r[2])
