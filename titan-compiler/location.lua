-- A Location datatype representing a point in a source code file
local location = {}

-- @param xs An ordered sequence of comparable items
-- @param v A value comparable to the items in the list
-- @return The position of the first occurrence of `v` in the sequence or the
-- position of the first item greater than `v` in the sequence, otherwise.
-- Inserting `v` at the returned position will always keep the sequence ordered.
local function binary_search(xs, v)
    -- Invariants:
    --   1 <= lo <= hi <= #xs + 1
    --   xs[i] < v , if i < lo
    --   xs[i] >= v, if i >= hi
    local lo = 1
    local hi = #xs + 1
    while lo < hi do
        -- Average, rounded down (lo <= mid < hi)
        -- Lua's logical right shift works here even if the addition overflows
        local mid = (lo + hi) >> 1
        if xs[mid] < v then
            lo = mid + 1
        else
            hi = mid
        end
    end
    return lo
end

local newline_cache = setmetatable({}, { __mode = "k" })

-- Converts an Lpeg file position into more familiar line and column numbers.
--
-- @param subject The contents of an entire source code file
-- @param pos A position in this file, as an absolute integer index
-- @return The line and column number at the specified position.
local function get_line_number(subject, pos)
    local newlines
    if newline_cache[subject] then
        newlines = newline_cache[subject]
    else
        newlines = {}
        for n in subject:gmatch("()\n") do
            table.insert(newlines, n)
        end
        newline_cache[subject] = newlines
    end
    local line = binary_search(newlines, pos)
    local col  = pos - (newlines[line - 1] or 0)
    return line, col
end

function location.new(filename, line, col)
    return {
        filename = filename,
        line = line,
        col = col
    }
end

function location.from_pos(filename, source, pos)
    local line, col = get_line_number(source, pos)
    return location.new(filename, line, col)
end

function location.format_error(loc, fmt, ...)
    return string.format("%s:%d:%d: "..fmt,
            loc.filename, loc.line, loc.col,
            ...)
end

return location
