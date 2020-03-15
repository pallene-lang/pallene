-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

m = require "examples.rectangle.rectangle"
local r = { width = 10.5, height = 5.0 }
result = m.find_area(r)
print("The area of rectangle with width " .. r.width .. " and height " .. r.height .. " is " .. result .. "!")
