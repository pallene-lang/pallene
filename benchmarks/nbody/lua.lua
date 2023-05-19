math.ln = math.log; local m = {}











function m.new_body(
    x, y, z,
    vx, vy, vz, mass)

    return {
        x = x,
        y = y,
        z = z,
        vx = vx,
        vy = vy,
        vz = vz,
        mass = mass,
    }
end

function m.offset_momentum(bodies)
    local n = #bodies
    local px = 0.0
    local py = 0.0
    local pz = 0.0
    for i= 1, n do
      local bi = bodies[i]
      local bim = bi.mass
      px = px + (bi.vx * bim)
      py = py + (bi.vy * bim)
      pz = pz + (bi.vz * bim)
    end

    local sun = bodies[1]
    local solar_mass = sun.mass
    sun.vx = sun.vx - px / solar_mass
    sun.vy = sun.vy - py / solar_mass
    sun.vz = sun.vz - pz / solar_mass
end

function m.advance(bodies, dt)
    local n = #bodies
    for i = 1, n do
        local bi = bodies[i]
        for j=i+1,n do
          local bj = bodies[j]
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
    end
    for i = 1, n do
        local bi = bodies[i]
        bi.x = bi.x + dt * bi.vx
        bi.y = bi.y + dt * bi.vy
        bi.z = bi.z + dt * bi.vz
    end
end

function m.advance_multiple_steps(nsteps, bodies, dt)
    for _ = 1, nsteps do
        m.advance(bodies, dt)
    end
end

function m.energy(bodies)
    local n = #bodies
    local e = 0.0
    for i = 1, n do
        local bi = bodies[i]
        local vx = bi.vx
        local vy = bi.vy
        local vz = bi.vz
        e = e + 0.5 * bi.mass * (vx*vx + vy*vy + vz*vz)
        for j = i+1, n do
          local bj = bodies[j]
          local dx = bi.x-bj.x
          local dy = bi.y-bj.y
          local dz = bi.z-bj.z
          local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
          e = e - (bi.mass * bj.mass) / distance
        end
    end
    return e
end

return m
