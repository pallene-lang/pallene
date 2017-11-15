local util = {}

function util.get_file_contents(filename)
    local f, err = io.open(filename, "r")
    if not f then
        return false, err
    end
    local s = f:read("a")
    f:close()
    if not s then
        return false, "unable to open file " .. filename
    else
        return s
    end
end

function util.set_file_contents(filename, contents)
    local f, err = io.open(filename, "w")
    if not f then
        return false, err
    end
    f:write(contents)
    f:close()
    return true
end

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

function util.get_line_number(subject, pos)
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

return util
