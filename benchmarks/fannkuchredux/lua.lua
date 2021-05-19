local m;m = {}

function m.fannkuch(N)

    local initial_perm = {}
    for i = 1, N do
        initial_perm[i] = i
    end

    local perm = {} -- Work copy, allocated once

    local count = {}
    count[1] = 0
    local r = N

    local perm_count = 0
    local max_flips = 0
    local checksum = 0

    while true do

        -- Flip the pancakes, working on a copy of the permutation

        do
            for i = 1, N do
                perm[i] = initial_perm[i]
            end

            local flips_count = 0
            local h = perm[1]
            while h > 1 do
                 local i = 1
                 local j = h
                 repeat
                    local a = perm[i]
                    local b = perm[j]
                    perm[i] = b
                    perm[j] = a
                    i = i + 1
                    j = j - 1
                until i >= j

                flips_count = flips_count + 1
                h = perm[1]
            end

            if flips_count > max_flips then
                max_flips = flips_count
            end

            if perm_count % 2 == 0 then
                checksum = checksum + flips_count
            else
                checksum = checksum - flips_count
            end
        end

        -- Go to next permutation

        while r > 1 do
            count[r] = r
            r = r - 1
        end

        while true do
            if r == N then
                return { checksum, max_flips }
            end

            local tmp = initial_perm[1]
            for i = 1, r do
                initial_perm[i] = initial_perm[i+1]
            end
            initial_perm[r+1] = tmp

            local r1 = r+1
            count[r1] = count[r1] - 1
            if count[r1] > 0 then break end
            r = r1
        end
        perm_count = perm_count + 1
    end
end

return m
