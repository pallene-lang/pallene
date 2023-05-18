math.ln = math.log; local m = {}

-- Return A[i][j], for the infinite matrix A
--
--  A = 1/1  1/2  1/4 ...
--      1/3  1/5  ... ...
--      1/6  ...  ... ...
--      ...  ...  ... ...
local function A(i, j)
    local ij = i + j
    return 1.0 / ((ij-1) * (ij-2) * 0.5 + i)
end

-- Multiply vector v by matrix A
local function MultiplyAv(N, v, out)
    for i = 1, N do
        local s = 0.0
        for j = 1, N do
            s = s + A(i,j) * v[j]
        end
        out[i] = s
    end
end

-- Multiply vector v by matrix A transposed
local function MultiplyAtv(N, v, out)
    for i=1, N do
        local s = 0.0
        for j = 1, N do
            s = s + A(j,i) * v[j]
        end
        out[i] = s
    end
end

-- Multiply vector v by matrix A and then by matrix A transposed
local function MultiplyAtAv(N, v, out)
    local u = {}
    MultiplyAv(N, v, u)
    MultiplyAtv(N, u, out)
end

function m.Approximate(N)
    -- Create unit vector
    local u = {}
    for i = 1, N do
        u[i] = 1.0
    end

    -- 20 steps of the power method
    local v = {}
    for _ = 1, 10 do
        MultiplyAtAv(N, u, v)
        MultiplyAtAv(N, v, u)
    end

    local vBv = 0.0
    local vv  = 0.0
    for i = 1, N do
        local ui = u[i]
        local vi = v[i]
        vBv = vBv + ui*vi
        vv  = vv  + vi*vi
    end

    return math.sqrt(vBv/vv)
end

return m
