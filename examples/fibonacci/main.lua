-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

package = require "examples.fibonacci.fibonacci"
n = 10
result = package.fibonacci(n)
for i = 1, #result do
    print(result[i])
end
