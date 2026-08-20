local test = require "examples.sets.sets"

local p = {}

test.setx(p, 30)
test.sety(p, 40)
print(p.x) -- prints `nil`. Wrong!
print(p.y) -- prints `nil`. Wrong!
assert(30 == p.x)
assert(40 == p.y)

test.setnil(p)
assert(nil == p.x)

test.setany(p, "hello")
assert("hello", p.x)
