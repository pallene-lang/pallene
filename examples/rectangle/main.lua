-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local rect = require "examples.rectangle.rectangle"
local r = { width = 10.5, height = 5.0 }
local result = rect.find_area(r)
print(string.format(
    "The area of rectangle with width %.2f and height %.2f is %.2f",
    r.width, r.height, result))
