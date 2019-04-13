local function new(x, y)
    return { x = x, y = y }
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

return {
    new = new,
    centroid = centroid
}
