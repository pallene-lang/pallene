local test = require(arg[1])
local N = tonumber(arg[2]) or 100000000

local data = test.create(1.1, 2.2)

test.run(data)
