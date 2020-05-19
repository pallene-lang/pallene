-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local sum_of_array = require "examples.sum_of_array.sum_of_array"
local result = sum_of_array.sum({ 5.25, 2.50 })
print(string.format("5.25 + 2.50 = %.2f", result))
