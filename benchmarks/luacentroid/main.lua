local point = require(arg[1])
local N     = tonumber(arg[2]) or 10000
local nrep  = tonumber(arg[3]) or 50000

local arr = {}
for i = 1, N do
    local d = i * 0.31415
    arr[i] = point.new(d, -d)
end

local function centroid(points, nrep)
    local x = 0.0
    local y = 0.0
    local npoints = #points
    for _ = 1, nrep do
        x = 0.0
        y = 0.0
        for i = 1, npoints do
            local p = points[i]
            x = x + p.x
            y = y + p.y
        end
    end
    return { x = x / npoints, y = y / npoints }
end

local r = centroid(arr, nrep)
print(r.x, r.y)
