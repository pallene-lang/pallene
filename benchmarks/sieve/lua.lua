local _M = {}

function _M.sieve(N)
    local is_prime = {}
    table.insert(is_prime, false)
    for n = 2, N do
        table.insert(is_prime, true)
    end

    local nprimes = 0
    local primes = {}

    for n = 1, N do
        if is_prime[n] then
            nprimes = nprimes + 1;
            table.insert(primes, n)
            for m = n+n, N, n do
                is_prime[m] = false
            end
        end
    end

    return primes
end

return _M
