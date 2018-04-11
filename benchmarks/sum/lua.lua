local _M = {}
function _M.sum(arr, nrep)
    local s = 0.0
    for rep = 1, nrep do
        for i = 1, #arr do
            s = s + arr[i]
        end
    end
    return s
end
return _M
