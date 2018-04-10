local sum = require(arg[1])

local arr = {}
for i = 1, 1e6 do
    arr[i] = 0.01
end

print(sum.sum(arr, 100))
