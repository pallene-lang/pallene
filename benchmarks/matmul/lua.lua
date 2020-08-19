local matmul;
function matmul(A, B)
    local C = {}
    local NI = #A
    local NK = #B
    local NJ = #B[1]
    for i = 1, NI do
        local line = {}
        for j = 1, NJ do
            line[j] = 0.0
        end
        C[i] = line
    end
    for k = 1, NK do
        local Bk = B[k]
        for i = 1, NI do
            local Aik = A[i][k]
            local Ci = C[i]
            for j = 1, NJ do
                Ci[j] = Ci[j] + Aik * Bk[j]
            end
        end
    end
    return C
end

return {
    matmul = matmul,
}
