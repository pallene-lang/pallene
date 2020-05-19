-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local fac = require "examples.factorial.factorial"
local n = 5
local result = fac.factorial(n)
print(string.format("The factorial of %d is %d.", n, result))
