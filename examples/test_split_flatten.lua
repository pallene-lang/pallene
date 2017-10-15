local titan = require "artisanal"

local t = {}

for i = 1, 1000 do
  t[#t+1] = i * 10
end

local tt = titan.split(t, 3)
local ttt = titan.flatten(tt)

assert(#t == #ttt)
for i = 1, #t do
  assert(t[i] == ttt[i])
end
