-- Copyright (c) 2026, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local matrix = require "matrix"
local vector = require "vector"

local function rotation_matrix(theta)
    local c = math.cos(theta)
    local s = math.sin(theta)
    return {
        { c, -s },
        { s,  c },
    }
end

-- Rotate the points of a unit square by pi/4 radians (45 degrees) counterclockwise.
local rotation = rotation_matrix(math.pi / 4)

local square = {
    { 1.0, 1.0 },
    { 2.0, 1.0 },
    { 2.0, 2.0 },
    { 1.0, 2.0 },
}

print(string.format("The diagonal of the square is %.4f",
    vector.norm({ square[3][1] - square[1][1], square[3][2] - square[1][2] })))

print("Rotating pi/4 radians...")
local rotated_square = {}
for i = 1, #square do
    local v = square[i]
    local w = matrix.mul_vector(rotation, v)
    rotated_square[i] = w
    print(string.format("(%.1f, %.1f) -> (%.1f, %.1f)", v[1], v[2], w[1], w[2]))
end

print(string.format("The diagonal of the (rotated) square is %.4f",
    vector.norm({ rotated_square[3][1] - rotated_square[1][1], rotated_square[3][2] - rotated_square[1][2] })))


print("Scaling 2x...")
local scaled_square = {}
for i = 1, #rotated_square do
    local v = rotated_square[i]
    local w = vector.scale(v, 2.0)
    print(string.format("(%.1f, %.1f) -> (%.1f, %.1f)", v[1], v[2], w[1], w[2]))
    scaled_square[i] = w
end

print(string.format("The diagonal of the square (after rotation) is %.4f",
    vector.norm({ scaled_square[3][1] - scaled_square[1][1], scaled_square[3][2] - scaled_square[1][2] })))
