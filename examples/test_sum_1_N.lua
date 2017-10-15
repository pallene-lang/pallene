local N    = arg[1] and tonumber(arg[1]) or 500000000

local f = require("artisanal").sum

print("N="..N)
local r = f(N)
print(r)

