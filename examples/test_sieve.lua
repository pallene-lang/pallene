local N    = arg[1] and tonumber(arg[1]) or 100

local f = require("artisanal").sieve

local ps = f(N)
print(#ps)
