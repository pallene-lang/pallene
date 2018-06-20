local point = require(arg[1])

local arr = {}
for i = 1, 1e4 do
    arr[i] = point.new(i * math.pi, i * math.pi)
end

local r = point.centroid(arr, 10000)
print(x, y)
