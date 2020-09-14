local life   = require(arg[1])
local nsteps = tonumber(arg[2]) or 2000

local GLIDER = {
    { 0,0,1, },
    { 1,0,1, },
    { 0,1,1, }
}

local N = 40
local M = 80

local curr_cells = life.new_canvas(N, M)
local next_cells = life.new_canvas(N, M)

for i = 1, 8 do
    for j = 1, 16 do
        local i0 = 5*i + 1 + j*j
        local j0 = 5*j + 1
        life.spawn(N, M, curr_cells, GLIDER, i0, j0)
    end
end

io.write("\027[2J")	-- ANSI clear screen
for _ = 1, nsteps do
    life.step(N, M, curr_cells, next_cells)
    curr_cells, next_cells = next_cells, curr_cells
    io.write("\027[H") -- ANSI home cursor
    life.draw(N, M, curr_cells)
end
