local matmul = {}

function matmul.matmul(A, B)
    local C = {}
    for i = 1, #A do
        local line = {}
        for j = 1, #B[i] do
            local cij = 0
            for k = 1, #A[i] do
                cij = cij + A[i][k] * B[k][j]
            end
            line[j] = cij
        end
        C[i] = line
    end
    return C
end

return matmul
