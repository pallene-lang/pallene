--
-- This scripts finds examples of initialization orders that result in a Lua
-- sequence with some of its elements stored in the hash part.
--

local table_parts = require 'table_parts'

local function all_different(xs)
    for i = 1, #xs do
        for j = 1, #xs do
            if (i ~= j) and xs[i] == xs[j] then
                return false
            end
        end
    end
    return true
end

local function combinations()
    local n = 0
    for a = 1, 5 do
        for b = 1,4 do
            for c = 1,5 do
                for d = 1,5 do
                    for e = 1,5 do
                        if all_different{a,b,c,d,e} then
                            local t = {}
                            t[a] = a*10
                            t[b] = b*10
                            t[c] = c*10
                            t[d] = d*10
                            t[e] = e*10
                            if table_parts.has_hash(t) then
                                n = n + 1
                                print(a,b,c,d,e)
                            end
                        end
                    end
                end
            end
        end
    end
end

combinations()
