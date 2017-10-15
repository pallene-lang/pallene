local mod = require "artisanal"

local f = mod.filltable

local N    = arg[1] and tonumber(arg[1]) or 1000

print("N="..N)
local r = f(N)
print(type(r))
