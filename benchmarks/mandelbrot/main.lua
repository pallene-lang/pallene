-- Mandelbrot benchmark from benchmarks game
-- https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/mandelbrot.html
--
-- Translated from the Java version found at
-- https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/mandelbrot-java-1.html
--
--  * I don't use any explicit buffering. In my experiments it speeds up the
--    program by less than 10%, while considerably increasing the complexity.
--  * The LuaJIT version needs to be separate, due to the lack of bitwise ops.

local mandelbrot = require(arg[1])
local N   = tonumber(arg[2]) or 100
--local REP = tonumber(arg[3]) or 1

io.write(string.format("P4\n%d %d\n", N, N))
mandelbrot.mandelbrot(N)
