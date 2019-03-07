local function binsearch(t, x)
    -- lo <= x <= hi
    local lo = 1
    local hi = #t

    local steps = 0

    while lo < hi do

        local mid = lo + (hi - lo) // 2
        steps = steps + 1

        local tmid = t[mid]

        if x == tmid then
            return steps
        elseif x < tmid then
            hi = mid - 1
        else
            lo = mid + 1
        end
    end

    return steps
end

local function test(t, nrep)
    local s = 0
    for i = 1, nrep do
        if binsearch(t, i) ~= 22 then
            s = s + 1
        end
    end
    return s
end

return {
    binsearch = binsearch,
    test = test,
}
