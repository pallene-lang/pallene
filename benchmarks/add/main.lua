local add = require(arg[1])

local x = 0.0
local add_add = add.add
for i = 1, 1e7 do
     x = add_add(x, 3.14)
end
print(x)
