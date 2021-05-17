local m;m = {}

function m.new(x, y)
    return { x, y }
end

function m.clone(x)
    return m.new(x[1], x[2])
end

function m.conj(x)
    return m.new(x[1], -x[2])
end

function m.add(x, y)
    return m.new(x[1] + y[1], x[2] + y[2])
end

function m.mul(x, y)
    return m.new(x[1] * y[1] - x[2] * y[2], x[1] * y[2] + x[2] * y[1])
end

function m.norm2(x)
    local n = m.mul(x, m.conj(x))
    return n[1]
end

return m
