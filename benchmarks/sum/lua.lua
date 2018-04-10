local _M = {}
function _M.sum(arr, n)
    local s = 0.0
    for i = 1, n do
        for i = 1, #arr do
            s = s + arr[i]
        end
    end
    return s
end
return _M
