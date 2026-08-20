local test = require "examples.sets2.sets"

local p = {x = 10, y = 20}
-- assert(10 == test.getx(p))
-- assert(20 == test.gety(p))

p.x = "hello"
assert("hello" == test.getany(p))

p.x = nil

print(p.x)
print(test.getany(p))
print(test.getnil(p))

assert(nil == test.getany(p))
assert(nil == test.getnil(p))

