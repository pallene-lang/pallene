local matmul = require(arg[1])
local N   = tonumber(arg[2]) or 800
local REP = tonumber(arg[3]) or math.max(1.0, 2 * (800/N)^3)

-- Suggested values for N, REP:
--  800,    2
--  400,   16
--  200,  128
--  100, 1024

local A = {}
for i = 1, N do
    A[i] = {}
    for j = 1, N do
        A[i][j] = (i + j) * 3.1415
    end
end

local C
for _ = 1, REP do
    C = matmul.matmul(A, A)
end
print("#C", #C, #C[1])
print("C[1][1]", C[1][1])
