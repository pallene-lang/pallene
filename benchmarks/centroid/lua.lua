local new, centroid;
function new(x, y)
    return { x, y }
end

function centroid(points, nrep)
    local x = 0.0
    local y = 0.0
    local npoints = #points
    for _ = 1, nrep do
        x = 0.0
        y = 0.0
        for i = 1, npoints do
            local p = points[i]
            x = x + p[1]
            y = y + p[2]
        end
    end
    return { x / npoints, y / npoints }
end

return {
    new = new,
    centroid = centroid,
}
