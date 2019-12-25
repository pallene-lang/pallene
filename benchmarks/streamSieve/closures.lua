
-- Simple streams library for building infinite lists.
-- A stream is a cons of a value and a thunk that computes the next value
-- when applied.

-- (any, any->any) -> any
local function make_stream(v, f)
    return {v=v, f=f}
end

local function stream_head(st)
    return st.v
end

local function stream_tail(st)
    return st.f(st.v)
end

local function stream_get(st, n)
    for _ = 1, n-1 do
        st = stream_tail(st)
    end
    return stream_head(st)
end

local function stream_take(st, n)
    local elems = {}
    for i = 1, n do
        elems[i] = stream_head(st)
        st = stream_tail(st)
    end
    return elems
end

----------------------------------------------

-- Build a stream of integers starting from 1
local function count_from(n)
    return make_stream(n, function(i) return count_from(i+1) end)
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

--
local prime_stream = sieve(count_from(2))

local function get_prime(n)
    return stream_get(prime_stream, n)
end

local N = tonumber(arg[1])
print(string.format("primes(%d) = %d", N, get_prime(N)))
