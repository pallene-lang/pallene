--
-- This benchmark generates a mandelbrot set picture in Netpbm file format.
-- It is loosely inspired by the similar benchmark from the benchmarks game.
-- This version puts a lot of weight on the boundary between Lua and the Pallene, because the main
-- loop is in Lua, calling Pallene functions. LuaJIT tends to do very well here because it optimizes
-- away many of the table allocations.
--

local Complex = require(arg[1])
local N       = tonumber(arg[2]) or 256

local function level(x, y)
    local c = Complex.new(x, y)
    local z = Complex.clone(c)
    local l = 0
    repeat
        z = Complex.add(Complex.mul(z, z), c)
        l = l + 1
    until Complex.norm2(z) > 4.0 or l > 255
    return l - 1
end

local xmin = -2.0
local xmax = 2.0
local ymin = -2.0
local ymax = 2.0

local dx = (xmax - xmin) / N
local dy = (ymax - ymin) / N

io.write("P2\n")
io.write(N, " ", N, " ", 255, "\n")

for i = 1, N do
    local x = xmin + (i - 1) * dx
    for j = 1, N do
        local y = ymin + (j - 1) * dy
        if j > 1 then io.write(" ") end
        io.write(level(x, y))
    end
    io.write("\n")
end

