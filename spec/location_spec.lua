-- Copyright (c) 2021, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local Location = require "pallene.Location"

local function check_get_line_number(text, line_numbers)
    for i = 1, #line_numbers do
        local expected_line = line_numbers[i][1]
        local expected_col  = line_numbers[i][2]
        local loc = Location.from_pos("(location_spec)", text, i)
        assert.same(expected_line, loc.line)
        assert.same(expected_col,  loc.col)
    end
end

describe("Source file location", function()

    it("gets line numbers from strings", function()
        check_get_line_number("a\nbbbbbb\n\ncde\nfghhh", {
            { 1, 1 },
            { 1, 2 },
            { 2, 1 },
            { 2, 2 },
            { 2, 3 },
            { 2, 4 },
            { 2, 5 },
            { 2, 6 },
            { 2, 7 },
            { 3, 1 },
            { 4, 1 },
            { 4, 2 },
            { 4, 3 },
            { 4, 4 },
            { 5, 1 },
            { 5, 2 },
            { 5, 3 },
            { 5, 4 },
            { 5, 5 },
        })
    end)

    it("gets line numbers from strings (no newlines in program)", function()
        check_get_line_number("abc", {
            { 1, 1 },
            { 1, 2 },
            { 1, 3 },
        })
    end)
end)
