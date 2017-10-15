local N    = arg[1] and tonumber(arg[1]) or 5000

local sort = require("artisanal").sort

local function make_input(N)
    local xs = {}
    for i=1,N do
        xs[i] = N - i + 1
    end
    return xs
end

local function print_array(xs)
    print( "{" .. table.concat(xs, ", ") .. "}" )
end

local function is_sorted(xs)
    for i=2,#xs do
        if xs[i-1] > xs[i] then
            return false
        end
    end
    return true
end

local xs = make_input(N)
print('before', is_sorted(xs))
sort(xs)
print('after', is_sorted(xs))
