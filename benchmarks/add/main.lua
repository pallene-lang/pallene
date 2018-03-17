local add = require(arg[1])

local x = 0
for i = 1, 1e7 do
     x = add.add(x, 3.14)
end
print(x)
