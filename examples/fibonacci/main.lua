-- Copyright (c) 2026, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local fib = require "fibonacci"
local n = 10
local result = fib.fibonacci(n)
for i = 1, #result do
    print(result[i])
end
