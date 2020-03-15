-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

package = require "examples.factorial.factorial"

n = 5
result = package.factorial(n)
print("The factorial of " .. n .. " is " .. result .. ".")
