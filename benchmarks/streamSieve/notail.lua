
-- Simple streams library for building infinite lists.
-- Based on the implementation from Racket, but modified to use explicit
-- parameters instead of closures

local function make_stream(head, state, get_tail)
    return { head, state, get_tail }
end

local function stream_head(st)
    return st[1]
end

local function stream_tail(st)
    return (st[3](st[2]))
end

local function stream_get(st, n)
    for _ = 1, n-1 do
        st = stream_tail(st)
    end
    return (stream_head(st))
end

----------------------------------------------

-- Build a stream of integers starting from 1

local count_from, _tail1

function count_from(n)
    return (make_stream(n, n, _tail1))
end

function _tail1(i)
    return (count_from(i+1))
end

-- Filter all multiples of n

local sift, _tail2

function sift(n, st)
    local hd = stream_head(st)
    local tl = stream_tail(st)
    while hd % n == 0 do
        st = tl
        hd = stream_head(st)
        tl = stream_tail(st)
    end
    local state = { n, tl }
    return (make_stream(hd, state, _tail2))
end

function _tail2(state)
    return (sift(state[1], state[2]))
end

-- Naive sieve of Erasthostenes

local sieve, _tail3

function sieve(st)
    local n  = stream_head(st)
    local tl = stream_tail(st)
    local state = { n, tl }
    return (make_stream(n, state, _tail3))
end

function _tail3(state)
    return (sieve(sift(state[1], state[2])))
end

--

local function get_prime(n)
    local prime_stream = sieve(count_from(2))
    return (stream_get(prime_stream, n))
end

return {
    get_prime = get_prime
}
