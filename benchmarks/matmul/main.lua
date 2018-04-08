local matmul = require(arg[1])

function print_mat(A)
    for i = 1, #A do
        print(table.concat(A[i], " "))
    end
end

local N = 300

local BIG1 = {}
for i = 1, N do
    BIG1[i] = {}
    for j = 1, N do
        BIG1[i][j] = i + j
    end
end

BIG2 = BIG1

local C
for i = 1, 1 do
    C = matmul.matmul(BIG1, BIG2)
end
print("#C=", #C, #C[1])
--print_mat(C)


