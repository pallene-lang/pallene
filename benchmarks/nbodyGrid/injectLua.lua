local function update_speeds(bi, bj, dt)
    local dx = bi.x - bj.x
    local dy = bi.y - bj.y
    local dz = bi.z - bj.z

    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
    local mag = dt / (dist * dist * dist)

    local bjm = bj.mass * mag
    bi.vx = bi.vx - (dx * bjm)
    bi.vy = bi.vy - (dy * bjm)
    bi.vz = bi.vz - (dz * bjm)

    local bim = bi.mass * mag
    bj.vx = bj.vx + (dx * bim)
    bj.vy = bj.vy + (dy * bim)
    bj.vz = bj.vz + (dz * bim)
end

local function update_position(bi, dt)
    bi.x = bi.x + dt * bi.vx
    bi.y = bi.y + dt * bi.vy
    bi.z = bi.z + dt * bi.vz
end

local function advance(nsteps, bodies, dt)
    local n = #bodies
    for _ = 1, nsteps do
        for i = 1, n do
            local bi = bodies[i]
            for j=i+1,n do
                local bj = bodies[j]
                update_speeds(bi, bj, dt)
            end
        end
        for i = 1, n do
            local bi = bodies[i]
            update_position(bi, dt)
        end
    end
end

return {
    update_speeds = update_speeds,
    update_position = update_position,
    advance = advance,

    inject_update_speeds   = function(f) update_speeds = f end,
    inject_update_position = function(f) update_position = f end,
}
