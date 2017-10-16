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

local newline_cache = setmetatable({}, { __mode = "k" })

--- Given ordered sequence `xs`, search for `v`,
-- If `v` is not found, return the position of
-- the lowest item `x` in `xs` such that `x > v`.
-- @param xs An ordered sequence of comparable items
-- @param v A value comparable to the items in the list
-- @param min (optional) The initial position (default 1)
-- @param max (optional) The final position (default `#xs`)
-- @return The position of `v`, or the position of
-- the lowest item greater than it. Inserting `v` at
-- the returned position will always keep the sequence
-- ordered.
local function binary_search(xs, v, min, max)
    min, max = min or 1, max or #xs
    if v < xs[min] then
        return min
    elseif v > xs[max] then
        return max + 1
    end
    local i = (min + max) // 2
    if v < xs[i] then
        return binary_search(xs, v, min, i - 1)
    elseif v > xs[i] then
        return binary_search(xs, v, i + 1, max)
    end
    return i
end

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
    return line, pos - (newlines[line - 1] or 0)
end

return util
