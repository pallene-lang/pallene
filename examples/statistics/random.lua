-- Copyright (c) 2026, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- This is an example implementing Lehmer generator as an use case example for
-- what reasons Pallene would benefit from calling Lua. Real code would want to call Lua's
-- builtin `math.random`, that isn't available in Pallene.

local m = {}

local MODULUS    = 2147483647 -- 2^31 - 1
local MULTIPLIER = 16807

function m.sample(count, seed)
    local x = seed << 1 | 1

    local xs = {}
    for i = 1, count do
        x = (x * MULTIPLIER) % MODULUS
        xs[i] = x * 1.0
    end
    return xs
end

return m
