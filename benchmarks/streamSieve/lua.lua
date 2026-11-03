-- Naive stream-based prime sieve benchmark. (Based on a typed-racket benchmark)
-- Based on https://github.com/bennn/gtp-benchmarks/tree/master/benchmarks/sieve

local m = {}

----------------------------------------------

-- Simple streams library for building infinite lists.
-- A stream is a cons of a value and a thunk that computes the next value.



-- TODO: with recursive types, this could be (any -> Stream)


local function make_stream(first, rest)
    return {first=first, rest=rest}
end

local function stream_head(st)
    return st.first
end

local function stream_tail(st)
    return st.rest()
end

local function stream_get(st, n)
    for _ = 1, n-1 do
        st = stream_tail(st)
    end
    return stream_head(st)
end

----------------------------------------------

-- Build a stream of integers starting from 1
local function count_from(n)
    return make_stream(n, function() return count_from(n+1) end)
end

-- Filter all multiples of n
local function sift(n, st)
    local hd = stream_head(st)
    local tl = stream_tail(st)
    if hd % n == 0 then
        return sift(n, tl)
    else
        return make_stream(hd, function() return sift(n, tl) end)
    end
end

-- Naive sieve of Erasthostenes
local function sieve(st)
    local hd = stream_head(st)
    local tl = stream_tail(st)
    return make_stream(hd, function() return sieve(sift(hd, tl)) end)
end

----

function m.get_prime(n)
    local primes = sieve(count_from(2))
    return stream_get(primes, n)
end

return m
