math.ln = math.log; local m = {}

function m.sieve(N)
    local is_prime = {}
    is_prime[1] = false
    for n = 2, N do
        is_prime[n] = true
    end

    local nprimes = 0
    local primes = {}

    for n = 1, N do
        if is_prime[n] then
            nprimes = nprimes + 1;
            primes[nprimes] = n
            for m = n+n, N, n do
                is_prime[m] = false
            end
        end
    end

    return primes
end

return m
