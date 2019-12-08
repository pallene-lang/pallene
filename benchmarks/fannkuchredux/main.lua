-- Fannkuch-redux benchmark from benchmarks game
-- https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/fannkuchredux.html
--
-- Based on the C version found at:
-- https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/fannkuchredux-gcc-1.html
--
-- Code by Hugo Gualandi, translated to Lua from the C version. The thing with
-- the count vector is complicated, but we need to copy that from the original
-- program to ensure that the permutation order is the right one.
--
-- * note: I made the function return a list of values because Pallene cannot
--   return multiple values yet, or print the integer checksum.
--
-- Expected output (N = 7):
--    228
--    Pfannkuchen(7) = 16
--
-- Expected output (N = 12):
--    3968050
--    Pfannkuchen(12) = 65

local fannkuch =  require(arg[1])
local N   = tonumber(arg[2]) or 7 -- or 12
--local REP = tonumber(arg[3]) or 1

local ret = fannkuch.fannkuch(N)
local checksum = ret[1]
local flips    = ret[2]
print(checksum)
print(string.format("Pfannkuchen(%d) = %d", N, flips))
