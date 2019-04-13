-- The Computer Language Benchmarks Game
-- http://benchmarksgame.alioth.debian.org/
-- contributed by Mike Pall
-- modified by Geoff Leyland
-- modified by Mario Pernici

local function makebody(x, y, z, vx, vy, vz, mass)
    return { x = x, y = y, z = z, vx = vx, vy = vy, vz = vz, mass = mass }
end

local function advance (bodies, dt)
  for i=1, #bodies do
    local bi = bodies[i]
    local bix, biy, biz, bimass = bi.x, bi.y, bi.z, bi.mass
    local bivx, bivy, bivz = bi.vx, bi.vy, bi.vz
    for j=i+1, #bodies do
      local bj = bodies[j]
      local dx, dy, dz = bix-bj.x, biy-bj.y, biz-bj.z
      local dist2 = dx*dx + dy*dy + dz*dz
      --local mag = math.sqrt(dist2)
      local mag = dist2
      mag = dt / (mag * dist2)
      local bm = bj.mass*mag
      bivx = bivx - (dx * bm)
      bivy = bivy - (dy * bm)
      bivz = bivz - (dz * bm)
      bm = bimass*mag
      bj.vx = bj.vx + (dx * bm)
      bj.vy = bj.vy + (dy * bm)
      bj.vz = bj.vz + (dz * bm)
    end
    bi.vx = bivx
    bi.vy = bivy
    bi.vz = bivz
    bi.x = bix + dt * bivx
    bi.y = biy + dt * bivy
    bi.z = biz + dt * bivz
  end
end

return {
    makebody = makebody,
    advance = advance,
}
