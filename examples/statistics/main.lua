-- Copyright (c) 2026, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local statistics = require "statistics"

local xs = statistics.sample(200, 1)

print(string.format("generated %d numbers", #xs))
print(string.format("mean:   %.2f", statistics.mean(xs)))
print(string.format("stddev: %.2f", statistics.stddev(xs)))
print(string.format("min:    %d", statistics.min(xs)))
print(string.format("max:    %d", statistics.max(xs)))
