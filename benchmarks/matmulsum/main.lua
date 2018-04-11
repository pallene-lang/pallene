local matmul = require(arg[1])

local N = 600

local BIG1 = {}
for i = 1, N do
    BIG1[i] = {}
    for j = 1, N do
        BIG1[i][j] = (i + j) * math.pi
    end
end

BIG2 = BIG1

local s = matmul.matmul(BIG1, BIG2)
print(s)
