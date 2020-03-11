m = require "examples.rectangle"
local r = { width = 10.5, height = 5.0 }
result = m.find_area(r)
print("The area of rectangle with width " .. r.width .. " and height " .. r.height .. " is " .. result .. "!")
