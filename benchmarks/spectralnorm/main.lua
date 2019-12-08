local spectralnorm = require(arg[1])
local N   = tonumber(arg[2]) or 1000 -- or 5500
--local REP = tonumber(arg[3]) or 1

-- Spectral norm benchmark from benchmarks game
-- https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/spectralnorm.html
--
-- Original C# code:
-- https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/spectralnorm-csharpcore-1.html
--
-- Code by Hugo Gualandi. It is translated directly from the C# specification
-- with the following main differences:
--   - The A() function uses 1-based indexing instead of 0-based
--   - The A() function multiplies by 0.5 instead of doing an integer division.
--     According to my measurements, this is not a significant difference, and
--     the multiplication by 0.5 has the advantage that it works on LuaJIT too.
--   - Some of the "out" tables not initialized with zeroes.
--
-- Expected output (N = 5500):
--    1.274224153

local res = spectralnorm.Approximate(N)
print(string.format("%0.9f", res))
